defmodule Requiem.OutgoingPacket.SenderSupervisor do
  use Supervisor

  alias Requiem.OutgoingPacket.SenderWorker

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
    num = Keyword.fetch!(opts, :number_of_senders)
    interval = Keyword.fetch!(opts, :buffering_interval)
    transport = Keyword.fetch!(opts, :transport)

    0..num
    |> Enum.map(fn idx ->
      {SenderWorker,
       [
         handler: handler,
         worker_index: idx,
         buffering_interval: interval,
         transport: transport
       ]}
    end)
    |> Enum.reduce([], fn x, acc -> [x | acc] end)
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
