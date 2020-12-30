defmodule Requiem.QUIC.Socket do
  alias Requiem.QUIC.NIF

  @spec open(binary, non_neg_integer, pid) :: {:ok, term} | {:error, :system_error}
  def open(host, port, pid) do
    address = "#{host}:#{port}"
    NIF.socket_open(address, pid)
  end

  @spec send(term, term, binary) :: :ok | {:error, :system_error | :not_found}
  def send(sock, peer, packet) do
    NIF.socket_send(sock, peer, packet)
  end

  @spec address_parts(term) :: {:ok, binary, non_neg_integer}
  def address_parts(address) do
    NIF.socket_address_parts(address)
  end

end
