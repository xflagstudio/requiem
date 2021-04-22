defmodule Requiem.QUIC.Socket do
  alias Requiem.QUIC.NIF

  @spec cpu_num() :: integer
  def cpu_num() do
    NIF.cpu_num()
  end

  @spec new(integer) ::
          {:ok, integer} | {:error, :system_error | :socket_error}
  def new(num_node) do
    NIF.socket_new(num_node)
  end

  @spec start(integer, binary, non_neg_integer, pid, [pid]) ::
          :ok | {:error, :system_error | :socket_error}
  def start(socket_ptr, host, port, pid, target_pids) do
    NIF.socket_start(socket_ptr, "#{host}:#{port}", pid, target_pids)
  end

  @spec destroy(integer) :: :ok | {:error, :system_error | :not_found}
  def destroy(socket_ptr) do
    NIF.socket_destroy(socket_ptr)
  end

  @spec address_parts(term) :: {:ok, binary, non_neg_integer}
  def address_parts(address) do
    NIF.socket_address_parts(address)
  end

  @spec address_from_string(binary) :: {:ok, term} | {:error, :bad_format}
  def address_from_string(address) do
    NIF.socket_address_from_string(address)
  end
end
