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
          dispatcher_index: non_neg_integer,
          dispatchers: [pid],
          port: non_neg_integer,
          host: binary
        }

  defstruct handler: nil,
            dispatcher_index: 0,
            dispatchers: [],
            port: 0,
            host: ""

  def send(handler, address, packet) do
    Tracer.trace(__MODULE__, "@send")
    QUIC.Socket.send(handler, address.raw, packet)
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :handler) |> name()
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    dispatchers =
      DispatcherRegistry.gather(
        Keyword.fetch!(opts, :handler),
        Keyword.fetch!(opts, :number_of_dispatchers)
      )

    state = new(opts, dispatchers)

    capacity = Keyword.fetch!(opts, :event_capacity)
    timeout = Keyword.fetch!(opts, :polling_timeout)

    case QUIC.Socket.open(
           state.handler,
           state.host,
           state.port,
           self(),
           capacity,
           timeout
         ) do
      :ok ->
        Logger.info("<Requiem.Transport.RustUDP> opened")
        Process.flag(:trap_exit, true)
        {:ok, state}

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

    {pid, new_state} = choose_dispatcher(state)
    DispatcherWorker.dispatch(pid, address, data)
    {:noreply, new_state}
  end

  def handle_info({:socket_error, reason}, state) do
    Logger.error("<Requiem.Transport.RustUDP> socket error. #{inspect(reason)}")
    {:stop, {:shutdown, :socket_error}, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("<Requiem.Transport.RustUDP> @terminate: #{inspect(reason)}")
    QUIC.Socket.close(state.handler)
    :ok
  end

  defp new(opts, dispatchers) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      dispatcher_index: 0,
      dispatchers: dispatchers,
      port: Keyword.fetch!(opts, :port),
      host: Keyword.fetch!(opts, :host)
    }
  end

  defp choose_dispatcher(state) do
    pid = Enum.at(state.dispatchers, state.dispatcher_index)
    state = update_dispatcher_index(state)
    {pid, state}
  end

  defp update_dispatcher_index(state) do
    if state.dispatcher_index >= length(state.dispatchers) - 1 do
      %{state | dispatcher_index: 0}
    else
      %{state | dispatcher_index: state.dispatcher_index + 1}
    end
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
