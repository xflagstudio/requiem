defmodule Requiem.Transport.GenUDP do
  require Logger
  require Requiem.Tracer

  use GenServer
  use Bitwise

  alias Requiem.Address
  alias Requiem.IncomingPacket.DispatcherRegistry
  alias Requiem.IncomingPacket.DispatcherWorker
  alias Requiem.Tracer

  @max_quic_packet_size 1350

  @type t :: %__MODULE__{
          handler: module,
          number_of_dispatchers: non_neg_integer,
          dispatcher_index: non_neg_integer,
          port: non_neg_integer,
          sock: port
        }

  defstruct handler: nil,
            number_of_dispatchers: 0,
            dispatcher_index: 0,
            port: 0,
            sock: nil

  def batch_send(handler, batch) do
    handler |> name() |> GenServer.cast({:batch_send, batch})
  end

  def send(handler, address, packet) do
    handler |> name() |> GenServer.cast({:send, address, packet})
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :handler) |> name()
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    state = new(opts)

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

  def handle_cast({:batch_send, batch}, state) do
    Tracer.trace(__MODULE__, "@batch_send")

    batch
    |> Enum.each(fn {address, packet} ->
      send_packet(state.sock, address, packet)
    end)

    {:noreply, state}
  end

  defp find_dispatcher(state, retry_count) when retry_count < 3 do
    case DispatcherRegistry.lookup(state.handler, state.dispatcher_index) do
      {:ok, pid} ->
        {:ok, pid, update_dispatcher_index(state)}

      {:error, :not_found} ->
        state |> update_dispatcher_index() |> find_dispatcher(retry_count + 1)
    end
  end

  defp find_dispatcher(_state, _retry_count) do
    {:error, :not_found}
  end

  defp update_dispatcher_index(state) do
    if state.dispatcher_index >= state.number_of_dispatchers - 1 do
      %{state | dispatcher_index: 0}
    else
      %{state | dispatcher_index: state.dispatcher_index + 1}
    end
  end

  @impl GenServer
  def handle_info({:udp, _sock, address, port, data}, state) do
    Tracer.trace(__MODULE__, "@received")
    packet = IO.iodata_to_binary(data)

    if byte_size(data) <= @max_quic_packet_size do
      Tracer.trace(__MODULE__, "available size of packet. try to dispatch")

      case find_dispatcher(state, 0) do
        {:ok, pid, new_state} ->
          DispatcherWorker.dispatch(pid, Address.new(address, port), packet)
          {:noreply, new_state}

        {:error, :not_found} ->
          Logger.error("<Requiem.Transport.GenUDP> can't find dispatcher process")
          {:noreply, state}
      end
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

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      number_of_dispatchers: Keyword.fetch!(opts, :number_of_dispatchers),
      dispatcher_index: 0,
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
