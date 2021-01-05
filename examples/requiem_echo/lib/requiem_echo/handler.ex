defmodule RequiemEcho.Handler do
  require Logger
  use Requiem, otp_app: :requiem_echo

  @impl Requiem
  def init(conn, client) do
    Logger.debug("<Handler> init")
    Logger.debug("<Handler> origin: #{client.origin}, path: #{client.path}")
    {:ok, conn, %{}}
  end

  @impl Requiem
  def handle_info(_request, conn, state) do
    Logger.debug("<Handler> handle_info")
    {:noreply, conn, state}
  end

  @impl Requiem
  def handle_cast(_request, conn, state) do
    Logger.debug("<Handler> handle_cast")
    {:noreply, conn, state}
  end

  @impl Requiem
  def handle_call(_request, _from, conn, state) do
    Logger.debug("<Handler> handle_call")
    {:reply, :ok, conn, state}
  end

  @impl Requiem
  def handle_stream(stream_id, data, conn, state) do
    Logger.debug("<Handler> handle_stream(#{stream_id}, #{data})")

    if Requiem.StreamId.is_bidi?(stream_id) do
      stream_send(stream_id, data)
      {:ok, conn, state}
    else
      {stream_id, conn2} = Requiem.ConnectionState.create_new_stream_id(conn, :uni)
      stream_send(stream_id, data)
      {:ok, conn2, state}
    end
  end

  @impl Requiem
  def handle_dgram(data, conn, state) do
    Logger.debug("<Handler> handle_dgram(#{data})")
    dgram_send(data)
    {:ok, conn, state}
  end

  @impl Requiem
  def terminate(reason, _conn, _state) do
    Logger.debug("<Handler> terminate: #{inspect(reason)}")
    :ok
  end
end
