defmodule Requiem.QUIC.Socket do
  alias Requiem.QUIC.NIF

  @spec open(integer, binary, non_neg_integer, pid, [pid]) ::
          {:ok, integer} | {:error, :system_error | :cant_bind}
  def open(num_node, host, port, pid, target_pids) do
    NIF.socket_open(num_node, "#{host}:#{port}", pid, target_pids)
  end

  @spec close(integer) :: :ok | {:error, :system_error | :not_found}
  def close(socket_ptr) do
    NIF.socket_close(socket_ptr)
  end

  @spec address_parts(term) :: {:ok, binary, non_neg_integer}
  def address_parts(address) do
    NIF.socket_address_parts(address)
  end
end
