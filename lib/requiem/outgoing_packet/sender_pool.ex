defmodule Requiem.OutgoingPacket.SenderPool do
  @behaviour Requiem.OutgoingPacket.Sender.Behaviour

  use Supervisor

  alias Requiem.OutgoingPacket.SenderWorker

  @impl Requiem.OutgoingPacket.Sender.Behaviour
  def send(handler, address, packet) do
    handler
    |> pool_name()
    |> :poolboy.transaction(fn pid ->
      SenderWorker.send(pid, address, packet)
    end)
  end

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :handler) |> supervisor_name()

    %{
      id: name,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :handler) |> supervisor_name()
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    opts
    |> children()
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp children(opts) do
    handler = Keyword.fetch!(opts, :handler)
    transport = Keyword.fetch!(opts, :transport)
    interval = Keyword.fetch!(opts, :buffering_interval)
    size = Keyword.fetch!(opts, :pool_size)
    overflow = Keyword.fetch!(opts, :pool_max_overflow)

    name = pool_name(handler)
    pool_opts = pool_opts(name, size, overflow)

    sender_opts = [
      handler: handler,
      transport: transport,
      buffering_interval: interval
    ]

    [:poolboy.child_spec(name, pool_opts, sender_opts)]
  end

  defp pool_opts(name, size, overflow) do
    [
      {:name, {:local, name}},
      {:worker_module, SenderWorker},
      {:size, size},
      {:strategy, :fifo},
      {:max_overflow, overflow}
    ]
  end

  def supervisor_name(handler),
    do: Module.concat([handler, __MODULE__, Supervisor])

  def pool_name(handler),
    do: Module.concat(handler, __MODULE__)
end
