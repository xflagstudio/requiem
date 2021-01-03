defmodule Requiem.Transport.RustUDP do
  @moduledoc """
  This is an experimental module that aims to achieve high UDP throughput by using NIF.
  """

  use GenServer
  require Logger
  require Requiem.Tracer

  alias Requiem.DispatcherRegistry
  alias Requiem.QUIC
  alias Requiem.Tracer

  @type t :: %__MODULE__{
          handler: module
        }

  defstruct handler: nil

  def send(handler, address, packet) do
    Tracer.trace(__MODULE__, "@send")
    QUIC.Socket.send(handler, address.raw, packet)
  end

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

    capacity = Keyword.fetch!(opts, :event_capacity)
    timeout = Keyword.fetch!(opts, :polling_timeout)
    host = Keyword.fetch!(opts, :host)
    port = Keyword.fetch!(opts, :port)

    case QUIC.Socket.open(
           state.handler,
           host,
           port,
           self(),
           dispatchers,
           capacity,
           timeout
         ) do
      :ok ->
        Logger.info("<Requiem.Transport.RustUDP> opened #{host}:#{port}")
        Process.flag(:trap_exit, true)
        {:ok, state}

      {:error, reason} ->
        Logger.error(
          "<Requiem.Transport.RustUDP> failed to open UDP port #{to_string(state.port)}: #{
            inspect(reason)
          }"
        )

        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_info({:socket_error, reason}, state) do
    Logger.error("<Requiem.Transport.RustUDP> socket error. #{inspect(reason)}")
    {:stop, {:shutdown, :socket_error}, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("<Requiem.Transport.RustUDP> @terminate: #{inspect(reason)}")
    QUIC.Socket.close(state.handler)
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler)
    }
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
