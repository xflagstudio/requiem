defmodule Requiem.Transport.RustUDP do
  @moduledoc """
  This is an experimental module that aims to achieve high UDP throughput by using NIF.
  """

  use GenServer
  require Logger
  require Requiem.Tracer

  alias Requiem.Address
  alias Requiem.DispatcherRegistry
  alias Requiem.DispatcherWorker
  alias Requiem.QUIC
  alias Requiem.Tracer

  @type t :: %__MODULE__{
          handler: module,
          number_of_dispatchers: non_neg_integer,
          dispatcher_index: non_neg_integer,
          port: non_neg_integer,
          host: binary,
          event_capacity: non_neg_integer,
          polling_timeout: non_neg_integer,
          sock: port
        }

  defstruct handler: nil,
            number_of_dispatchers: 0,
            dispatcher_index: 0,
            port: 0,
            host: "",
            event_capacity: 0,
            polling_timeout: 0,
            sock: nil

  def batch_send(handler, batch) do
    handler |> name() |> GenServer.cast({:batch_send, batch})
  end

  def send(handler, address, packet) do
    handler |> name() |> GenServer.cast({:send, address, packet})
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :handler) |> name()
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    state = new(opts)

    case QUIC.Socket.open(
           state.host,
           state.port,
           self(),
           state.event_capacity,
           state.polling_timeout
         ) do
      {:ok, sock} ->
        Logger.info("<Requiem.Transport.RustUDP> opened")
        Process.flag(:trap_exit, true)
        {:ok, %{state | sock: sock}}

      {:error, reason} ->
        Logger.error(
          "<Requiem.Transport.RustUDP> failed to open UDP port #{to_string(state.port)}: #{
            inspect(reason)
          }"
        )

        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_cast({:send, address, packet}, state) do
    Tracer.trace(__MODULE__, "@send")
    send_packet(state.sock, address, packet)
    {:noreply, state}
  end

  def handle_cast({:batch_send, batch}, state) do
    Tracer.trace(__MODULE__, "@batch_send")

    batch
    |> Enum.each(fn {address, packet} ->
      send_packet(state.sock, address, packet)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:__packet__, peer, data}, state) do
    Tracer.trace(__MODULE__, "@received")
    {:ok, host, port} = QUIC.Socket.address_parts(peer)

    address =
      if byte_size(host) == 4 do
        <<n1, n2, n3, n4>> = host
        Address.new({n1, n2, n3, n4}, port, peer)
      else
        <<
          n1::unsigned-integer-size(16),
          n2::unsigned-integer-size(16),
          n3::unsigned-integer-size(16),
          n4::unsigned-integer-size(16),
          n5::unsigned-integer-size(16),
          n6::unsigned-integer-size(16),
          n7::unsigned-integer-size(16),
          n8::unsigned-integer-size(16)
        >> = host

        Address.new({n1, n2, n3, n4, n5, n6, n7, n8}, port, peer)
      end

    case find_dispatcher(state, 0) do
      {:ok, pid, new_state} ->
        DispatcherWorker.dispatch(pid, address, data)
        {:noreply, new_state}

      {:error, :not_found} ->
        Logger.error("<Requiem.Transport.RustUDP> can't find dispatcher process")
        {:noreply, state}
    end
  end

  def handle_info({:socket_error, reason}, state) do
    Logger.error("<Requiem.Transport.RustUDP> socket error. #{inspect(reason)}")
    {:stop, {:shutdown, :socket_error}, state}
  end

  @impl GenServer
  def terminate(reason, _state) do
    Logger.info("<Requiem.Transport.RustUDP> @terminate: #{inspect(reason)}")
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      number_of_dispatchers: Keyword.fetch!(opts, :number_of_dispatchers),
      dispatcher_index: 0,
      port: Keyword.fetch!(opts, :port),
      host: Keyword.fetch!(opts, :host),
      event_capacity: Keyword.get(opts, :event_capacity, 1024),
      polling_timeout: Keyword.get(opts, :polling_timeout, 10),
      sock: nil
    }
  end

  defp find_dispatcher(state, retry_count) when retry_count < 3 do
    case DispatcherRegistry.lookup(state.handler, state.dispatcher_index) do
      {:ok, pid} ->
        {:ok, pid, update_dispatcher_index(state)}

      {:error, :not_found} ->
        state |> update_dispatcher_index() |> find_dispatcher(retry_count + 1)
    end
  end

  defp find_dispatcher(_state, _retry_count) do
    {:error, :not_found}
  end

  defp update_dispatcher_index(state) do
    if state.dispatcher_index >= state.number_of_dispatchers - 1 do
      %{state | dispatcher_index: 0}
    else
      %{state | dispatcher_index: state.dispatcher_index + 1}
    end
  end

  defp send_packet(sock, address, packet) do
    Tracer.trace(__MODULE__, "send packet")

    QUIC.Socket.send(
      sock,
      address.raw,
      packet
    )
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
