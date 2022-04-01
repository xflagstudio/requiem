defmodule Requiem.NIF.SocketSender do
  alias Requiem.NIF.Bridge

  @spec get(integer, integer) :: {:ok, integer} | {:error, :system_error | :not_found}
  def get(socket_ptr, idx) do
    Bridge.socket_sender_get(socket_ptr, idx)
  end

  @spec send(integer, term, binary) :: :ok | {:error, :system_error | :not_found}
  def send(sender_ptr, address, packet) do
    Bridge.socket_sender_send(sender_ptr, address, packet)
  end

  @spec destroy(integer) :: :ok | {:error, :system_error | :not_found}
  def destroy(sender_ptr) do
    Bridge.socket_sender_destroy(sender_ptr)
  end
end
