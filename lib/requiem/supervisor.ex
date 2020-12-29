defmodule Requiem.Supervisor do
  @moduledoc """
  Root supervisor for all Requiem process tree.
  """
  use Supervisor
  alias Requiem.AddressTable
  alias Requiem.Config
  alias Requiem.QUIC
  alias Requiem.ConnectionRegistry
  alias Requiem.ConnectionSupervisor
  alias Requiem.OutgoingPacket.SenderPool
  alias Requiem.IncomingPacket.DispatcherPool
  alias Requiem.Transport.RustUDPSocket

  @spec child_spec(module, atom) :: Supervisor.child_spec()
  def child_spec(handler, otp_app) do
    %{
      id: handler |> name(),
      start: {__MODULE__, :start_link, [handler, otp_app]},
      type: :supervisor
    }
  end

  @spec start_link(module, Keyword.t()) :: Supervisor.on_start()
  def start_link(handler, otp_app) do
    name = handler |> name()
    Supervisor.start_link(__MODULE__, [handler, otp_app], name: name)
  end

  @impl Supervisor
  def init([handler, otp_app]) do
    handler |> QUIC.init()
    handler |> Config.setup(otp_app)
    handler |> AddressTable.init()
    handler |> children() |> Supervisor.init(strategy: :one_for_one)
  end

  defp children(handler) do
    trace = handler |> Config.get!(:trace)

    [
      {Registry, keys: :unique, name: ConnectionRegistry.name(handler)},
      {ConnectionSupervisor, handler},
      {SenderPool,
       [
         handler: handler,
         transport: RustUDPSocket,
         buffering_interval: handler |> Config.get!(:sender_buffering_interval),
         pool_size: handler |> Config.get!(:sender_pool_size),
         pool_max_overflow: handler |> Config.get!(:sender_pool_max_overflow)
       ]},
      {DispatcherPool,
       [
         handler: handler,
         transport: SenderPool,
         token_secret: handler |> Config.get!(:token_secret),
         conn_id_secret: handler |> Config.get!(:connection_id_secret),
         pool_size: handler |> Config.get!(:dispatcher_pool_size),
         pool_max_overflow: handler |> Config.get!(:dispatcher_pool_max_overflow),
         trace: trace
       ]},
      {RustUDPSocket,
       [
         handler: handler,
         dispatcher: DispatcherPool,
         port: handler |> Config.get!(:port),
         trace: trace
       ]}
    ]
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
