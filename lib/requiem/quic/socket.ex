defmodule Requiem.QUIC.Socket do
  alias Requiem.QUIC.NIF

  @spec start(module, list, binary, non_neg_integer) :: :ok | {:error, :system_error}
  def start(handler, pids, host, port) do
    address = "#{host}:#{port}"
    handler
    |> to_string()
    |> NIF.socket_start(pids, address)
  end

  @spec send(module, binary, term) :: :ok | {:error, :system_error | :not_found}
  def send(handler, packet, peer) do
    handler
    |> to_string()
    |> NIF.socket_send(packet, peer)
  end

  @spec stop(module) :: :ok | {:error, :system_error | :not_found}
  def stop(handler) do
    handler
    |> to_string()
    |> NIF.socket_stop()
  end

  @spec address_parts(term) :: {:ok, binary, non_neg_integer}
  def address_parts(address) do
    NIF.socket_address_parts(address)
  end

end
