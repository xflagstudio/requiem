defmodule Requiem.Transport.GenUDP do
  require Logger

  use GenServer
  use Bitwise

  @max_quic_packet_size 1350

  @type t :: %__MODULE__{
          handler: module,
          dispatcher: module,
          trace: boolean,
          port: non_neg_integer,
          sock: port
        }

  defstruct handler: nil,
            dispatcher: nil,
            trace: false,
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
        if state.trace do
          Logger.debug("<Requiem.Transport.GenUDP> opened UDP port #{inspect(state.port)}")
        end

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
    Logger.debug("<Requiem.Transport.GenUDP> @send")
    send_packet(state.sock, address, packet)
    {:noreply, state}
  end

  def handle_cast({:batch_send, batch}, state) do
    Logger.debug("<Requiem.Transport.GenUDP> @batch_send")

    batch
    |> Enum.each(fn {address, packet} ->
      send_packet(state.sock, address, packet)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:udp, _sock, address, port, data}, state) do
    Logger.debug("<Requiem.Transport.GenUDP> @received")
    packet = IO.iodata_to_binary(data)

    if byte_size(data) <= @max_quic_packet_size do
      Logger.debug("<Requiem.Transport.GenUDP> size is OK, dispatch")

      state.dispatcher.dispatch(
        state.handler,
        Requiem.Address.new(address, port),
        packet
      )
    end

    {:noreply, state}
  end

  def handle_info({:inet_reply, _, :ok}, state) do
    {:noreply, state}
  end

  def handle_info(request, state) do
    if state.trace do
      Logger.debug("<Requiem.Transport.GenUDP> unsupported handle_info: #{inspect(request)}")
    end

    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    if state.trace do
      Logger.debug("<Requiem.Transport.GenUDP> terminated: #{inspect(reason)}")
    end

    :gen_udp.close(state.sock)
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      dispatcher: Keyword.fetch!(opts, :dispatcher),
      port: Keyword.fetch!(opts, :port),
      trace: Keyword.get(opts, :trace, false),
      sock: nil
    }
  end

  defp send_packet(sock, address, packet) do
    # header = Requiem.Address.to_udp_header(address)
    # :erlang.port_command(sock, [header, packet])
    :gen_udp.send(sock, address.host, address.port, packet)
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
