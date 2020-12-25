defmodule Requiem.IncomingPacket.DispatcherPool do
  @behaviour Requiem.IncomingPacket.Dispatcher.Behaviour

  use Supervisor
  alias Requiem.IncomingPacket.DispatcherWorker

  @impl Requiem.IncomingPacket.Dispatcher.Behaviour
  def dispatch(handler, address, packet) do
    handler
    |> pool_name()
    |> :poolboy.transaction(fn pid ->
      DispatcherWorker.dispatch(pid, address, packet)
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
    token_secret = Keyword.fetch!(opts, :token_secret)
    conn_id_secret = Keyword.fetch!(opts, :conn_id_secret)
    trace = Keyword.get(opts, :trace, false)
    size = Keyword.fetch!(opts, :pool_size)
    overflow = Keyword.fetch!(opts, :pool_max_overflow)

    name = pool_name(handler)
    pool_opts = pool_opts(name, size, overflow)

    dispatcher_opts = [
      handler: handler,
      transport: transport,
      token_secret: token_secret,
      conn_id_secret: conn_id_secret,
      trace: trace
    ]

    [:poolboy.child_spec(name, pool_opts, dispatcher_opts)]
  end

  defp pool_opts(name, size, overflow) do
    [
      {:name, {:local, name}},
      {:worker_module, DispatcherWorker},
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
