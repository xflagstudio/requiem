defmodule Requiem.QUIC.Connection do
  alias Requiem.QUIC.NIF

  @spec accept(module, binary, binary, term) :: {:ok, term} | {:error, :system_error | :not_found}
  def accept(module, scid, odcid, peer) do
    module
    |> to_string()
    |> NIF.connection_accept(scid, odcid, peer)
  end

  @spec close(term, boolean, non_neg_integer, binary) ::
          :ok | {:error, :system_error | :already_closed}
  def close(conn, app, err, reason) do
    NIF.connection_close(conn, app, err, reason)
  end

  @spec is_closed?(term) :: boolean
  def is_closed?(conn) do
    NIF.connection_is_closed(conn)
  end

  @spec dgram_send(term, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def dgram_send(conn, data) do
    NIF.connection_dgram_send(conn, data)
  end

  @spec stream_send(term, non_neg_integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def stream_send(conn, stream_id, data) do
    NIF.connection_stream_send(conn, stream_id, data)
  end

  @spec on_packet(term, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def on_packet(conn, packet) do
    NIF.connection_on_packet(self(), conn, packet)
  end

  @spec on_timeout(term) :: {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def on_timeout(conn) do
    NIF.connection_on_timeout(conn)
  end
end
