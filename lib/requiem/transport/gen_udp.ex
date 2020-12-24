defmodule Requiem.Transport.GenUDP do
  require Logger

  use GenServer
  use Bitwise

  @max_quic_packet_size 1350

  @type t :: %__MODULE__{
          handler: module,
          dispatcher: module,
          loggable: boolean,
          port: non_neg_integer,
          sock: port
        }

  defstruct handler: nil,
            dispatcher: nil,
            loggable: false,
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
        if state.loggable do
          Logger.debug("<Requiem.Transport.UDP> opened UDP port #{inspect(state.port)}")
        end

        Process.flag(:trap_exit, true)
        {:ok, %{state | sock: sock}}

      {:error, reason} ->
        Logger.error(
          "<Requiem.Transport.UDP> failed to open UDP port #{to_string(state.port)}: #{
            inspect(reason)
          }"
        )

        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_cast({:send, address, packet}, state) do
    Logger.debug("udp:send")
    send_packet(state.sock, address, packet)
    {:noreply, state}
  end

  def handle_cast({:batch_send, batch}, state) do
    Logger.debug("udp:back_send")
    batch
    |> Enum.each(fn {address, packet} ->
      send_packet(state.sock, address, packet)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:udp, _sock, address, port, data}, state) do
    Logger.debug("incoming udp packet")
    packet = IO.iodata_to_binary(data)

    if byte_size(data) <= @max_quic_packet_size do
      state.dispatcher.dispatch(
        state.handler,
        Requiem.Address.new(address, port),
        packet
      )
    end

    {:noreply, state}
  end
  def handle_info(request, state) do
    if state.loggable do
      Logger.debug("<Requiem.Transport.UDP> unsupported handle_info: #{inspect request}")
    end
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    if state.loggable do
      Logger.debug("<Requiem.Transport.UDP> terminated: #{inspect reason}")
    end
    :gen_udp.close(state.sock)
    :ok
  end

  defp new(opts) do
    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      dispatcher: Keyword.fetch!(opts, :dispatcher),
      port: Keyword.fetch!(opts, :port),
      loggable: Keyword.get(opts, :loggable, false),
      sock: nil
    }
  end

  defp send_packet(sock, address, packet) do
    # TODO better performance
    #header = Requiem.Address.to_udp_header(address)
    #Port.command(sock, [header, packet])
    :gen_udp.send(sock, address.host, address.port, packet)
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
