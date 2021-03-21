defmodule Requiem.SenderWorker do
  require Logger
  require Requiem.Tracer
  use GenServer

  alias Requiem.Address
  alias Requiem.SenderRegistry
  alias Requiem.QUIC
  alias Requiem.Tracer

  @type t :: %__MODULE__{
          handler: module,
          worker_index: non_neg_integer,
          socket_ptr: integer,
          trace_id: binary
        }

  defstruct handler: nil,
            worker_index: 0,
            socket_ptr: 0,
            trace_id: ""

  @spec child_spec(Keyword.t()) :: map
  def child_spec(opts) do
    handler = Keyword.fetch!(opts, :handler)
    index = Keyword.fetch!(opts, :worker_index)

    %{
      id: name(handler, index),
      start: {__MODULE__, :start_link, [opts]},
      shutdown: 5_000,
      restart: :permanent,
      type: :worker
    }
  end

  @spec send(pid, Address.t(), binary) :: no_return
  def send(pid, address, packet) do
    GenServer.cast(pid, {:send, address, packet})
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    handler = Keyword.fetch!(opts, :handler)
    index = Keyword.fetch!(opts, :worker_index)
    GenServer.start_link(__MODULE__, opts, name: name(handler, index))
  end

  @impl GenServer
  def init(opts) do
    state = new(opts)
    Process.flag(:trap_exit, true)

    case SenderRegistry.register(
           state.handler,
           state.worker_index
         ) do
      {:ok, _pid} ->
        {:ok, sender_ptr} = QUIC.SocketSender.get(state.socket_ptr)
        {:ok, %{state | sender_ptr: sender_ptr}}

      {:error, {:already_registered, _pid}} ->
        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_cast({:send, address, packet}, state) do
    QUIC.SocketSender.send(state.socket_ptr, address.raw, packet)
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    SenderRegistry.unregister(state.handler, state.worker_index)
    QUIC.SocketSender.destroy(state.socket_ptr)
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      worker_index: Keyword.fetch!(opts, :worker_index),
      socket_ptr: Keyword.fetch!(opts, :socket_ptr),
      trace_id: inspect(self())
    }
  end

  defp name(handler, index),
    do: Module.concat([handler, __MODULE__, "Worker_#{index}"])
end
