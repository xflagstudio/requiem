defmodule Requiem.QUIC.Socket do
  alias Requiem.QUIC.NIF

  @spec open(module, binary, non_neg_integer, pid, non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error}
  def open(handler, host, port, pid, event_capacity, poll_interval) do
    handler
    |> to_string()
    |> NIF.socket_open("#{host}:#{port}", pid, event_capacity, poll_interval)
  end

  @spec send(module, term, binary) :: :ok | {:error, :system_error | :not_found}
  def send(handler, peer, packet) do
    handler
    |> to_string()
    |> NIF.socket_send(peer, packet)
  end

  @spec close(module) :: :ok | {:error, :system_error | :not_found}
  def close(handler) do
    handler
    |> to_string()
    |> NIF.socket_close()
  end

  @spec address_parts(term) :: {:ok, binary, non_neg_integer}
  def address_parts(address) do
    NIF.socket_address_parts(address)
  end
end
