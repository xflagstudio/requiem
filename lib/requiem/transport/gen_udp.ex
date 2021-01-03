defmodule Requiem.Transport.GenUDP do
  require Logger
  require Requiem.Tracer

  use GenServer
  use Bitwise

  alias Requiem.Address
  alias Requiem.DispatcherRegistry
  alias Requiem.DispatcherWorker
  alias Requiem.Tracer

  @max_quic_packet_size 1350

  @type t :: %__MODULE__{
          handler: module,
          dispatcher_index: non_neg_integer,
          dispatchers: [pid],
          port: non_neg_integer,
          sock: port
        }

  defstruct handler: nil,
            dispatcher_index: 0,
            dispatchers: [],
            port: 0,
            sock: nil

  def send(handler, address, packet) do
    handler |> name() |> GenServer.cast({:send, address, packet})
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

    state = new(opts, dispatchers)

    case :gen_udp.open(state.port, [:binary, active: true]) do
      {:ok, sock} ->
        Logger.info("<Requiem.Transport.GenUDP> opened UDP port #{inspect(state.port)}")

        Process.flag(:trap_exit, true)
        {:ok, %{state | sock: sock}}

      {:error, reason} ->
        Logger.error(
          "<Requiem.Transport.GenUDP> failed to open UDP port #{to_string(state.port)}: #{
            inspect(reason)
          }"
        )

        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_cast({:send, address, packet}, state) do
    Tracer.trace(__MODULE__, "@send")
    send_packet(state.sock, address, packet)
    {:noreply, state}
  end

  defp choose_dispatcher(state) do
    pid = Enum.at(state.dispatchers, state.dispatcher_index)
    state = update_dispatcher_index(state)
    {pid, state}
  end

  defp update_dispatcher_index(state) do
    if state.dispatcher_index >= length(state.dispatchers) - 1 do
      %{state | dispatcher_index: 0}
    else
      %{state | dispatcher_index: state.dispatcher_index + 1}
    end
  end

  @impl GenServer
  def handle_info({:udp, _sock, address, port, data}, state) do
    Tracer.trace(__MODULE__, "@received")

    if byte_size(data) <= @max_quic_packet_size do
      Tracer.trace(__MODULE__, "available size of packet. try to dispatch")

      {pid, new_state} = choose_dispatcher(state)
      DispatcherWorker.dispatch(pid, Address.new(address, port), data)
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:inet_reply, _, :ok}, state) do
    {:noreply, state}
  end

  def handle_info(request, state) do
    Tracer.trace(__MODULE__, "unsupported handle_info: #{inspect(request)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    Logger.info("<Requiem.Transport.GenUDP> @terminate: #{inspect(reason)}")
    :gen_udp.close(state.sock)
    :ok
  end

  defp new(opts, dispatchers) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      dispatcher_index: 0,
      dispatchers: dispatchers,
      port: Keyword.fetch!(opts, :port),
      sock: nil
    }
  end

  defp send_packet(sock, address, packet) do
    # header = Address.to_udp_header(address)
    # :erlang.port_command(sock, [header, packet])
    :gen_udp.send(sock, address.host, address.port, packet)
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
