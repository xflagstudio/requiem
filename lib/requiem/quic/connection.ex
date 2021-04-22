defmodule Requiem.QUIC.Connection do
  alias Requiem.QUIC.NIF

  @spec accept(integer, binary, binary, term, pid, non_neg_integer) ::
          {:ok, term} | {:error, :system_error | :not_found}
  def accept(config_ptr, scid, odcid, peer, sender_pid, stream_buf_size) do
    NIF.connection_accept(config_ptr, scid, odcid, peer, sender_pid, stream_buf_size)
  end

  @spec destroy(integer) ::
          :ok | {:error, :system_error | :already_closed}
  def destroy(conn) do
    NIF.connection_destroy(conn)
  end

  @spec close(integer, boolean, non_neg_integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def close(conn, app, err, reason) do
    NIF.connection_close(conn, app, err, reason)
  end

  @spec is_closed?(integer) :: boolean
  def is_closed?(conn) do
    NIF.connection_is_closed(conn)
  end

  @spec dgram_send(integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def dgram_send(conn, data) do
    NIF.connection_dgram_send(conn, data)
  end

  @spec stream_send(integer, non_neg_integer, binary, boolean) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def stream_send(conn, stream_id, data, fin) do
    NIF.connection_stream_send(conn, stream_id, data, fin)
  end

  @spec on_packet(integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def on_packet(conn, packet) do
    NIF.connection_on_packet(self(), conn, packet)
  end

  @spec on_timeout(integer) :: {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def on_timeout(conn) do
    NIF.connection_on_timeout(conn)
  end
end
