defmodule Requiem.Transport do
  use GenServer
  require Logger
  # require Requiem.Tracer

  alias Requiem.DispatcherRegistry
  alias Requiem.QUIC
  # alias Requiem.Tracer

  @type t :: %__MODULE__{
          handler: module,
          socket_ptr: integer
        }

  defstruct handler: nil,
            socket_ptr: 0

  def start_link(opts) do
    name = Keyword.fetch!(opts, :handler) |> name()
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    dispatchers =
      DispatcherRegistry.gather(
        Keyword.fetch!(opts, :handler),
        Keyword.fetch!(opts, :number_of_dispatchers)
      )

    state = new(opts)

    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    case QUIC.Socket.start(
           state.socket_ptr,
           host,
           port,
           self(),
           dispatchers
         ) do
      :ok ->
        Logger.info("<Requiem.Transport> socket started on #{host}:#{port}")
        Process.flag(:trap_exit, true)
        {:ok, state}

      {:error, :socket_error} ->
        Logger.error(
          "<Requiem.Transport> failed to bind UDP port, make sure that the values for this host(#{
            host
          }) and port(#{port}) are correct and that the port(#{port}) is not already in use."
        )

        {:stop, :normal}

      {:error, :system_error} ->
        Logger.error("<Requiem.Transport> failed to open UDP port #{to_string(port)}")

        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_info({:socket_error, reason}, state) do
    Logger.error("<Requiem.Transport> socket error. #{inspect(reason)}")
    {:stop, {:shutdown, :socket_error}, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("<Requiem.Transport> @terminate: #{inspect(reason)}")
    QUIC.Socket.destroy(state.socket_ptr)
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      socket_ptr: Keyword.fetch!(opts, :socket_ptr)
    }
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
