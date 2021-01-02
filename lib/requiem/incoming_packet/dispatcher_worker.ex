defmodule Requiem.IncomingPacket.DispatcherWorker do
  require Logger
  require Requiem.Tracer
  use GenServer

  alias Requiem.Address
  alias Requiem.Connection
  alias Requiem.ConnectionID
  alias Requiem.ConnectionSupervisor
  alias Requiem.QUIC
  alias Requiem.RetryToken
  alias Requiem.Tracer

  @type t :: %__MODULE__{
          handler: module,
          transport: module,
          token_secret: binary,
          conn_id_secret: binary,
    buffer: term,
          trace_id: binary
        }

  defstruct handler: nil,
            transport: nil,
            token_secret: "",
            conn_id_secret: "",
  buffer: nil,
            trace_id: ""

  @spec dispatch(pid, Address.t(), iodata()) ::
          :ok | {:error, :timeout}
  def dispatch(pid, address, packet) do
    try do
      GenServer.call(pid, {:packet, address, packet}, 100)
      :ok
    catch
      :exit, _ ->
        Tracer.trace(__MODULE__, "dispatch: failed")
        {:error, :timeout}
    end
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    state = new(opts)
    {:ok, buffer} = QUIC.Packet.create_buffer()
    {:ok, %{state| buffer: buffer}}
  end

  @impl GenServer
  def handle_call({:packet, address, packet}, _from, state) do
    case QUIC.Packet.parse_header(packet) do
      {:ok, scid, dcid, _token, _version, :initial, false} ->
        Tracer.trace(__MODULE__, state.trace_id, "@unsupported_version")
        handle_version_unsupported_packet(address, scid, dcid, state)

      {:ok, scid, dcid, token, version, :initial, true} ->
        Tracer.trace(__MODULE__, state.trace_id, "@init")
        handle_init_packet(address, packet, scid, dcid, token, version, state)

      {:ok, scid, dcid, _token, _version, packet_type, _version_supported} ->
        Tracer.trace(__MODULE__, state.trace_id, "@regular: #{packet_type}")
        handle_regular_packet(address, packet, scid, dcid, state)

      {:error, reason} ->
        if state.trace do
          Logger.debug(
            "<Requiem.IncomingPacket.DispatcherWorker:#{inspect(self())}> bad formatted packet: #{
              inspect(reason)
            }"
          )
        end

        :ok
    end

    {:reply, :ok, state}
  end

  def handle_call(_ev, _from, state) do
    if state.trace do
      Logger.info(
        "<Requiem.IncomingPacket.DispatcherWorker:#{inspect(self())}> unknown handle_call pattern"
      )
    end

    {:reply, :ok, state}
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      transport: Keyword.fetch!(opts, :transport),
      token_secret: Keyword.fetch!(opts, :token_secret),
      conn_id_secret: Keyword.fetch!(opts, :conn_id_secret),
      trace_id: inspect(self())
    }
  end

  defp handle_regular_packet(address, packet, _scid, dcid, state)
       when byte_size(dcid) == 20 or byte_size(dcid) == 0 do
    case ConnectionSupervisor.lookup_connection(state.handler, dcid, address) do
      {:ok, pid} ->
        Connection.process_packet(pid, address, packet)

      {:error, :not_found} ->
        :error
    end
  end

  defp handle_regular_packet(_address, _packet, _scid, _dcid, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@regular: bad dcid")
    :ok
  end

  defp handle_version_unsupported_packet(address, scid, dcid, state) do
    case QUIC.Packet.build_negotiate_version(state.buffer, scid, dcid) do
      {:ok, resp} ->
        state.transport.send(state.handler, address, resp)
        :ok

      error ->
        error
    end
  end

  defp handle_token_missing_packet(address, scid, dcid, version, state) do
    with {:ok, new_id} <-
           ConnectionID.generate_from_odcid(state.conn_id_secret, dcid),
         {:ok, token} <-
           RetryToken.create(address, dcid, new_id, state.token_secret),
         {:ok, resp} <-
           QUIC.Packet.build_retry(state.buffer, scid, dcid, new_id, token, version) do
      Tracer.trace(__MODULE__, state.trace_id, "@send")
      state.transport.send(state.handler, address, resp)
      :ok
    else
      {:error, _reason} -> :error
      :error -> :error
    end
  end

  defp handle_retry_packet(address, packet, scid, dcid, token, state)
       when byte_size(dcid) == 20 do
    Tracer.trace(__MODULE__, state.trace_id, "@validate")

    case RetryToken.validate(address, dcid, state.token_secret, token) do
      {:ok, odcid} ->
        Tracer.trace(__MODULE__, state.trace_id, "@validate_success")

        case create_connection_if_needed(
               state.handler,
               state.transport,
               address,
               scid,
               dcid,
               odcid
             ) do
          :ok ->
            handle_regular_packet(address, packet, scid, dcid, state)

          {:error, :system_error} ->
            :error
        end

        {:error, :system_error}
        :error
    end
  end

  defp handle_retry_packet(_address, _packet, _scid, _dcid, _token, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@validate: bad dcid")
    :error
  end

  defp handle_init_packet(address, packet, scid, dcid, token, version, state) do
    case ConnectionSupervisor.lookup_connection(state.handler, dcid, address) do
      {:ok, pid} ->
        Connection.process_packet(pid, address, packet)

      {:error, :not_found} ->
        if token == "" do
          Tracer.trace(__MODULE__, state.trace_id, "@token_missing_packet")
          handle_token_missing_packet(address, scid, dcid, version, state)
        else
          Tracer.trace(__MODULE__, state.trace_id, "@retry_packet")
          handle_retry_packet(address, packet, scid, dcid, token, state)
        end
    end
  end

  defp create_connection_if_needed(_handler, _transport, _address, _scid, <<>>, _odcid) do
    :ok
  end

  defp create_connection_if_needed(handler, transport, address, scid, dcid, odcid) do
    ConnectionSupervisor.create_connection(
      handler,
      transport,
      address,
      scid,
      dcid,
      odcid
    )
  end
end
