defmodule Requiem.QUIC.SocketSender do
  alias Requiem.QUIC.NIF

  @spec get(integer) :: {:ok, integer} | {:error, :system_error | :not_found}
  def get(socket_ptr) do
    NIF.socket_sender_get(socket_ptr)
  end

  @spec send(integer, term, binary) :: :ok | {:error, :system_error | :not_found}
  def send(sender_ptr, address, packet) do
    NIF.socket_sender_send(sender_ptr, address, packet)
  end

  @spec destroy(integer) :: :ok | {:error, :system_error | :not_found}
  def destroy(sender_ptr) do
    NIF.socket_sender_destroy(sender_ptr)
  end
end
