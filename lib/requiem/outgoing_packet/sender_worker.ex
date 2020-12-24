defmodule Requiem.OutgoingPacket.SenderWorker do
  use GenServer

  alias Requiem.Transport.Address

  @type t :: %__MODULE__{
          handler: module,
          transport: module,
          buffering_interval: non_neg_integer,
          buffer: list,
          timer: reference
        }

  defstruct handler: nil,
            transport: nil,
            buffering_interval: 0,
            buffer: [],
            timer: nil

  @spec send(pid, Address.t(), iodata()) ::
          :ok | {:error, :timeout}
  def send(pid, address, packet) do
    try do
      GenServer.call(pid, {:packet, address, packet}, 50)
      :ok
    catch
      :exit, _ -> {:error, :timeout}
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    state = new(opts)
    state = start_interval_timer(state)
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:packet, address, packet}, _from, %{buffering_interval: 0} = state) do
    state.transport.send(state.handler, address, packet)
    {:reply, :ok, state}
  end

  def handle_call({:packet, address, packet}, _from, state) do
    new_buffer = [{address, packet} | state.buffer]
    {:reply, :ok, %{state | buffer: new_buffer}}
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
      buffering_interval: Keyword.get(opts, :buffering_interval, 0),
      buffer: [],
      timer: nil
    }
  end
end
