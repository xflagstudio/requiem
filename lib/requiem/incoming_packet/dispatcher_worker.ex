defmodule Requiem.IncomingPacket.DispatcherWorker do
  require Logger
  use GenServer

  @type t :: %__MODULE__{
          handler: module,
          transport: module,
          token_secret: binary,
          conn_id_secret: binary,
          loggable: boolean
        }

  defstruct handler: nil,
            transport: nil,
            token_secret: "",
            conn_id_secret: "",
            loggable: false

  @spec dispatch(pid, Requiem.Address.t(), iodata()) ::
          :ok | {:error, :timeout}
  def dispatch(pid, address, packet) do
    try do
      GenServer.call(pid, {:packet, address, packet}, 50)
      :ok
    catch
      :exit, _ ->
        Logger.error("<Requiem.IncomingPacket.DispatcherWorker> failed to dispatch packet")
        {:error, :timeout}
    end
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    {:ok, new(opts)}
  end

  @impl GenServer
  def handle_call({:packet, address, packet}, _from, state) do
    case Requiem.QUIC.Packet.parse_header(packet) do
      {:ok, scid, dcid, _token, _version, false, _version_supported} ->
        Logger.debug("regular")
        handle_regular_packet(address, packet, scid, dcid, state)

      {:ok, scid, dcid, _token, _version, true, false} ->
        Logger.debug("unsupported version")
        handle_version_unsupported_packet(address, scid, dcid, state)

      {:ok, scid, dcid, <<>>, version, true, true} ->
        Logger.debug("token missing")
        handle_token_missing_packet(address, scid, dcid, version, state)

      {:ok, scid, dcid, token, _version, true, true} ->
        Logger.debug("init packet")
        handle_init_packet(address, packet, scid, dcid, token, state)

      {:error, reason} ->
        if state.loggable do
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
    if state.loggable do
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
      loggable: Keyword.get(opts, :loggable, false)
    }
  end

  defp handle_regular_packet(address, packet, scid, dcid, state) do
    Requiem.ConnectionSupervisor.dispatch_packet(
      state.handler,
      address,
      packet,
      scid,
      dcid,
      state.loggable
    )
  end

  defp handle_version_unsupported_packet(address, scid, dcid, state) do
    case Requiem.QUIC.Packet.build_negotiate_version(state.handler, scid, dcid) do
      {:ok, resp} ->
        state.transport.send(state.handler, address, resp)
        :ok

      error ->
        error
    end
  end

  defp handle_token_missing_packet(address, scid, dcid, version, state) do
    with {:ok, new_id} <- Requiem.QUIC.ConnectionID.generate_from_odcid(state.conn_id_secret, dcid),
         {:ok, token} <-
           Requiem.QUIC.RetryToken.create(address, dcid, new_id, state.token_secret),
         {:ok, resp} <-
           Requiem.QUIC.Packet.build_retry(state.handler, scid, dcid, new_id, token, version) do
      state.transport.send(state.handler, address, resp)
      :ok
    else
      {:error, _reason} -> :error
      :error -> :error
    end
  end

  defp handle_init_packet(address, packet, scid, dcid, token, state) do
    case Requiem.QUIC.RetryToken.validate(address, state.token_secret, token) do
      {:ok, odcid, _retry_scid} ->
        case Requiem.ConnectionSupervisor.create_connection(
               state.handler,
               state.transport,
               address,
               scid,
               dcid,
               odcid,
               state.loggable
             ) do
          :ok ->
            handle_regular_packet(address, packet, scid, dcid, state)

          {:error, :system_error} ->
            :error
        end

      :error ->
        :error
    end
  end
end
