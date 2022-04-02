defmodule Requiem.NIF.Connection do
  alias Requiem.NIF.Bridge

  @spec accept(integer, binary, binary, term, pid, non_neg_integer) ::
          {:ok, term} | {:error, :system_error | :not_found}
  def accept(config_ptr, scid, odcid, peer, sender_pid, stream_buf_size) do
    Bridge.connection_accept(config_ptr, scid, odcid, peer, sender_pid, stream_buf_size)
  end

  @spec accept_connect_request(integer) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def accept_connect_request(conn) do
    Bridge.connection_accept_connect_request(conn)
  end

  @spec reject_connect_request(integer, integer) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def reject_connect_request(conn, code) do
    Bridge.connection_reject_connect_request(conn, code)
  end

  @spec destroy(integer) ::
          :ok | {:error, :system_error | :already_closed}
  def destroy(conn) do
    Bridge.connection_destroy(conn)
  end

  @spec close(integer, boolean, non_neg_integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def close(conn, app, err, reason) do
    Bridge.connection_close(conn, app, err, reason)
  end

  @spec is_closed?(integer) :: boolean
  def is_closed?(conn) do
    Bridge.connection_is_closed(conn)
  end

  @spec dgram_send(integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def dgram_send(conn, data) do
    Bridge.connection_dgram_send(conn, data)
  end

  @spec open_stream(integer, boolean) ::
          {:ok, non_neg_integer, non_neg_integer} | {:error, :system_error | :already_closed}
  def open_stream(conn, is_bidi) do
    Bridge.connection_open_stream(conn, is_bidi)
  end

  @spec stream_send(integer, non_neg_integer, binary, boolean) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def stream_send(conn, stream_id, data, fin) do
    Bridge.connection_stream_send(conn, stream_id, data, fin)
  end

  @spec on_packet(integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def on_packet(conn, packet) do
    Bridge.connection_on_packet(self(), conn, packet)
  end

  @spec on_timeout(integer) :: {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def on_timeout(conn) do
    Bridge.connection_on_timeout(conn)
  end
end
