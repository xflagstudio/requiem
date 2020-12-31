defmodule Requiem.Transport.RustUDP do
  use GenServer
  require Logger

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

    case Requiem.QUIC.Socket.open(
           "0.0.0.0",
           state.port,
           self(),
           # event capacity
           1000,
           # poll interval (ms)
           5
         ) do
      {:ok, sock} ->
        Logger.debug("<Requiem.Transport.RustUDP> opened")
        Process.flag(:trap_exit, true)
        {:ok, %{state | sock: sock}}

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
  def handle_cast({:send, address, packet}, state) do
    Logger.debug("<Requiem.Transport.RustUDP> @send")
    send_packet(state.sock, address, packet)
    {:noreply, state}
  end

  def handle_cast({:batch_send, batch}, state) do
    Logger.debug("<Requiem.Transport.RustUDP> @batch_send")

    batch
    |> Enum.each(fn {address, packet} ->
      send_packet(state.sock, address, packet)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:__packet__, peer, data}, state) do
    Logger.debug("<Requiem.Transport.RustUDP> @received")
    {:ok, host, port} = Requiem.QUIC.Socket.address_parts(peer)

    address =
      if byte_size(host) == 4 do
        <<n1, n2, n3, n4>> = host
        Requiem.Address.new({n1, n2, n3, n4}, port, peer)
      else
        <<
          n1::unsigned-integer-size(16),
          n2::unsigned-integer-size(16),
          n3::unsigned-integer-size(16),
          n4::unsigned-integer-size(16),
          n5::unsigned-integer-size(16),
          n6::unsigned-integer-size(16),
          n7::unsigned-integer-size(16),
          n8::unsigned-integer-size(16)
        >> = host

        Requiem.Address.new({n1, n2, n3, n4, n5, n6, n7, n8}, port, peer)
      end

    state.dispatcher.dispatch(state.handler, address, data)
    {:noreply, state}
  end

  def handle_info({:socket_error, reason}, state) do
    Logger.debug("<Requiem.Transport.RustUDP> rust error: #{reason}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state) do
    if state.trace do
      Logger.debug("<Requiem.Transport.RustUDP> terminated: #{inspect(reason)}")
    end

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
    Logger.debug("<Requiem.Transport.RustUDP> send packet")

    Requiem.QUIC.Socket.send(
      sock,
      address.raw,
      packet
    )

    Logger.debug("<Requiem.Transport.RustUDP> send packet done")
  end

  defp name(handler),
    do: Module.concat(handler, __MODULE__)
end
