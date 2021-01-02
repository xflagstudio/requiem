defmodule Requiem.OutgoingPacket.SenderWorker do
  use GenServer

  alias Requiem.Address
  alias Requiem.OutgoingPacket.SenderRegistry

  @type t :: %__MODULE__{
          handler: module,
          transport: module,
          buffering_interval: non_neg_integer,
          worker_index: non_neg_integer,
          buffer: list,
          timer: reference
        }

  defstruct handler: nil,
            transport: nil,
            buffering_interval: 0,
            worker_index: 0,
            buffer: [],
            timer: nil

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

  @spec send(pid, Address.t(), iodata()) :: :ok
  def send(pid, address, packet) do
    GenServer.cast(pid, {:packet, address, packet})
    :ok
  end

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
        state = start_interval_timer(state)
        {:ok, state}

      {:error, {:already_registered, _pid}} ->
        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_cast({:packet, address, packet}, %{buffering_interval: 0} = state) do
    state.transport.send(state.handler, address, packet)
    {:noreply, state}
  end

  def handle_cast({:packet, address, packet}, state) do
    new_buffer = [{address, packet} | state.buffer]
    {:noreply, %{state | buffer: new_buffer}}
  end

  @impl GenServer
  def handle_info(:__timeout__, state) do
    if length(state.buffer) > 0 do
      state.transport.batch_send(
        state.handler,
        Enum.reverse(state.buffer)
      )
    end

    state = start_interval_timer(state)
    {:noreply, %{state | buffer: []}}
  end

  @impl GenServer
  def terminate(_reason, state) do
    cancel_interval_timer(state)
    SenderRegistry.unregister(state.handler, state.worker_index)
    :ok
  end

  defp start_interval_timer(state) do
    if state.buffering_interval != 0 do
      timer = Process.send_after(self(), :__timeout__, state.buffering_interval)
      %{state | timer: timer}
    else
      state
    end
  end

  defp cancel_interval_timer(state) do
    case state.timer do
      nil ->
        state

      timer ->
        Process.cancel_timer(timer)
        %{state | timer: nil}
    end
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      transport: Keyword.fetch!(opts, :transport),
      worker_index: Keyword.fetch!(opts, :worker_index),
      buffering_interval: Keyword.get(opts, :buffering_interval, 0),
      buffer: [],
      timer: nil
    }
  end

  defp name(handler, index),
    do: Module.concat([handler, __MODULE__, "Worker_#{index}"])
end
