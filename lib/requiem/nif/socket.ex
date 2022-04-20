defmodule Requiem.NIF.Socket do
  alias Requiem.NIF.Bridge

  @spec cpu_num() :: integer
  def cpu_num() do
    Bridge.cpu_num()
  end

  @spec new(integer, non_neg_integer, non_neg_integer) ::
          {:ok, integer} | {:error, :system_error | :socket_error}
  def new(num_node, read_timeout, write_timeout) do
    Bridge.socket_new(num_node, read_timeout, write_timeout)
  end

  @spec start(integer, binary, non_neg_integer, pid, [pid]) ::
          :ok | {:error, :system_error | :socket_error}
  def start(socket_ptr, host, port, pid, target_pids) do
    Bridge.socket_start(socket_ptr, "#{host}:#{port}", pid, target_pids)
  end

  @spec destroy(integer) :: :ok | {:error, :system_error | :not_found}
  def destroy(socket_ptr) do
    Bridge.socket_destroy(socket_ptr)
  end

  @spec address_parts(term) :: {:ok, binary, non_neg_integer}
  def address_parts(address) do
    Bridge.socket_address_parts(address)
  end

  @spec address_from_string(binary) :: {:ok, term} | {:error, :bad_format}
  def address_from_string(address) do
    Bridge.socket_address_from_string(address)
  end
end
