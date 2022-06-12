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
    0..(Keyword.fetch!(opts, :number_of_dispatchers) - 1)
    |> Enum.map(fn idx ->
      {DispatcherWorker,
       [
         worker_index: idx,
         handler: Keyword.fetch!(opts, :handler),
         token_secret: Keyword.fetch!(opts, :token_secret),
         conn_id_secret: Keyword.fetch!(opts, :conn_id_secret),
         number_of_sockets: Keyword.fetch!(opts, :number_of_sockets)
       ]}
    end)
    |> Enum.reduce([], fn x, acc -> [x | acc] end)
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
