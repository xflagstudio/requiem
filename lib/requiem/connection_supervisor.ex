defmodule Requiem.ConnectionSupervisor do
  @moduledoc """
  Supervisor for all QUIC connection.
  """

  require Requiem.Tracer

  use DynamicSupervisor

  alias Requiem.Address
  alias Requiem.Connection
  alias Requiem.ConnectionRegistry
  alias Requiem.Tracer

  @spec start_link(module) :: Supervisor.on_start()
  def start_link(handler) do
    name = handler |> name()
    DynamicSupervisor.start_link(__MODULE__, nil, name: name)
  end

  @impl DynamicSupervisor
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @spec lookup_connection(module, binary) ::
          {:ok, pid} | {:error, :not_found}
  def lookup_connection(handler, dcid),
    do: ConnectionRegistry.lookup(handler, dcid)

  @spec create_connection(
          module,
          Address.t(),
          binary,
          binary,
          binary,
          integer,
          pid
        ) ::
          :ok | {:error, :system_error}
  def create_connection(
        handler,
        address,
        scid,
        dcid,
        odcid,
        config_ptr,
        sender_pid
      ) do
    Tracer.trace(__MODULE__, "create cnonection: DCID:#{Base.encode16(dcid)}")

    case ConnectionRegistry.lookup(handler, dcid) do
      {:error, :not_found} ->
        opts = [
          handler: handler,
          address: address,
          dcid: dcid,
          scid: scid,
          odcid: odcid,
          config_ptr: config_ptr,
          sender_pid: sender_pid
        ]

        case start_child(opts) do
          {:error, reason} ->
            Tracer.trace(
              __MODULE__,
              "<Requiem.ConnectionSupervisor> failed to start connection: #{inspect(reason)}"
            )

            {:error, :system_error}

          _ ->
            :ok
        end

      {:ok, _pid} ->
        Tracer.trace(__MODULE__, "<Requiem.ConnectionSupervisor> connection already exists")

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
