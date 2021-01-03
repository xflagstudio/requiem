defmodule Requiem.DispatcherSupervisor do
  use Supervisor

  alias Requiem.DispatcherWorker

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(opts) do
    name = Keyword.fetch!(opts, :handler) |> name()

    %{
      id: name,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :handler) |> name()
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
    num = Keyword.fetch!(opts, :number_of_dispatchers)
    transport = Keyword.fetch!(opts, :transport)
    token_secret = Keyword.fetch!(opts, :token_secret)
    conn_id_secret = Keyword.fetch!(opts, :conn_id_secret)

    0..num
    |> Enum.map(fn idx ->
      {DispatcherWorker,
       [
         handler: handler,
         worker_index: idx,
         transport: transport,
         token_secret: token_secret,
         conn_id_secret: conn_id_secret
       ]}
    end)
    |> Enum.reduce([], fn x, acc -> [x | acc] end)
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
