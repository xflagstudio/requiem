defmodule Requiem.ConnectionSupervisor do
  @moduledoc """
  Supervisor for all QUIC connection.
  """

  require Logger

  use DynamicSupervisor

  alias Requiem.Address
  alias Requiem.AddressTable
  alias Requiem.Connection
  alias Requiem.ConnectionRegistry

  @spec start_link(module) :: Supervisor.on_start()
  def start_link(handler) do
    name = handler |> name()
    DynamicSupervisor.start_link(__MODULE__, nil, name: name)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec dispatch_packet(module, Address.t(), binary, binary, binary, boolean) :: :ok
  def dispatch_packet(handler, address, packet, _scid, dcid, trace) do
    Logger.debug(
      "<Requiem.ConectionSupervisor> loopup from registry: dcid:#{Base.encode16(dcid)}"
    )

    case lookup_connection(handler, dcid, address) do
      {:ok, pid} ->
        Logger.debug(
          "<Requiem.ConnectionSupervisor> found connection, pass packet to this process"
        )

        Connection.process_packet(pid, address, packet)
        :ok

      {:error, :not_found} ->
        if trace do
          Logger.debug(
            "<Requiem.ConnectionSupervisor> connection for #{Base.encode16(dcid)} not found, ignore"
          )
        end

        :ok
    end
  end

  @spec lookup_connection(module, binary, Address.t()) :: {:ok, binary} | {:error, :not_found}
  def lookup_connection(handler, <<>>, address) do
    case AddressTable.lookup(handler, address) do
      {:ok, dcid} ->
        ConnectionRegistry.lookup(handler, dcid)

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  def lookup_connection(handler, dcid, _address), do: ConnectionRegistry.lookup(handler, dcid)

  @spec create_connection(module, module, Address.t(), binary, binary, binary, boolean) ::
          :ok | {:error, :system_error}
  def create_connection(handler, transport, address, scid, dcid, odcid, trace) do
    Logger.debug("<Requiem.ConnectionSupervisor> create cnonection: DCID:#{Base.encode16(dcid)}")

    case ConnectionRegistry.lookup(handler, dcid) do
      {:error, :not_found} ->
        opts = [
          handler: handler,
          transport: transport,
          address: address,
          dcid: dcid,
          scid: scid,
          odcid: odcid,
          trace: trace
        ]

        case start_child(opts) do
          {:error, reason} ->
            if trace do
              Logger.info(
                "<Requiem.ConnectionSupervisor> failed to start connection: #{inspect(reason)}"
              )
            end

            {:error, :system_error}

          _ ->
            :ok
        end

      {:ok, _pid} ->
        if trace do
          Logger.info("<Requiem.ConnectionSupervisor> connection already exists")
        end

        :ok
    end
  end

  @spec start_child(Keyword.t()) :: DynamicSupervisor.on_start_child()
  def start_child(opts) do
    handler = Keyword.fetch!(opts, :handler)

    handler
    |> name()
    |> DynamicSupervisor.start_child({Connection, opts})
  end

  @spec terminate_child(module, pid) :: :ok | {:error, :not_found}
  def terminate_child(handler, pid) do
    handler |> name() |> DynamicSupervisor.terminate_child(pid)
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
