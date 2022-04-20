defmodule Requiem.Supervisor do
  @moduledoc """
  Root supervisor for all Requiem process tree.
  """
  require Logger
  use Supervisor
  alias Requiem.AddressTable
  alias Requiem.Config
  alias Requiem.NIF
  alias Requiem.ConnectionRegistry
  alias Requiem.ConnectionSupervisor
  alias Requiem.DispatcherSupervisor
  alias Requiem.DispatcherRegistry
  alias Requiem.SenderSupervisor
  alias Requiem.SenderRegistry
  alias Requiem.Transport

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
    handler |> Config.init(otp_app)

    if handler |> Config.get(:allow_address_routing) do
      handler |> AddressTable.init()
    end

    handler |> children() |> Supervisor.init(strategy: :one_for_one)
  end

  @spec children(module) :: [:supervisor.child_spec() | {module, term} | module]
  def children(handler) do
    socket_pool_size = Config.get!(handler, :socket_pool_size)

    num_socket =
      if socket_pool_size == 0 do
        NIF.Socket.cpu_num()
      else
        socket_pool_size
      end

    Logger.debug("num_socket: #{num_socket}")
    dispatcher_pool_size = Config.get!(handler, :dispatcher_pool_size) * num_socket

    read_timeout = Config.get!(handler, :socket_read_timeout)
    write_timeout = Config.get!(handler, :socket_write_timeout)

    case NIF.Socket.new(num_socket, read_timeout, write_timeout) do
      {:ok, socket_ptr} ->
        [
          {Registry, keys: :unique, name: ConnectionRegistry.name(handler)},
          {Registry, keys: :unique, name: DispatcherRegistry.name(handler)},
          {Registry, keys: :unique, name: SenderRegistry.name(handler)},
          {ConnectionSupervisor, handler},
          {SenderSupervisor,
           [
             handler: handler,
             socket_ptr: socket_ptr,
             number_of_senders: num_socket
           ]},
          {DispatcherSupervisor,
           [
             handler: handler,
             token_secret: handler |> Config.get!(:token_secret),
             conn_id_secret: handler |> Config.get!(:connection_id_secret),
             number_of_dispatchers: dispatcher_pool_size,
             number_of_sockets: num_socket,
             allow_address_routing: handler |> Config.get!(:allow_address_routing)
           ]},
          {Transport,
           [
             handler: handler,
             host: handler |> Config.get!(:host),
             port: handler |> Config.get!(:port),
             socket_ptr: socket_ptr,
             number_of_dispatchers: dispatcher_pool_size
           ]}
        ]

      {:error, reason} ->
        Logger.error("failed to create socket: #{inspect(reason)}")
        []
    end
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
