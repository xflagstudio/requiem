defmodule Requiem.QUIC.Socket do
  alias Requiem.QUIC.NIF

  @spec start_server(module, list, binary, non_neg_integer) :: :ok | {:error, :system_error}
  def start_server(handler, pids, host, port) do
    address = "#{host}:#{port}"
    handler
    |> to_string()
    |> NIF.server_start(pids, address)
  end

  @spec send(module, binary, term) :: :ok | {:error, :system_error | :not_found}
  def send(handler, packet, peer) do
    handler
    |> to_string()
    |> NIF.server_send(packet, peer)
  end

  @spec stop_server(module) :: :ok | {:error, :system_error | :not_found}
  def stop_server(handler) do
    handler
    |> to_string()
    |> NIF.server_stop()
  end

end
