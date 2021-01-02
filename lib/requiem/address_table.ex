defmodule Requiem.AddressTable do

  alias Requiem.Address

  @spec init(module) :: :ok
  def init(handler) do
    handler |> table_name() |> :ets.new([:set, :public, :named_table])
    :ok
  end

  @spec insert(module, Address.t(), binary) :: :ok
  def insert(handler, address, dcid) do
    handler
    |> table_name()
    |> :ets.insert({Address.to_binary(address), dcid})

    :ok
  end

  @spec lookup(module, Address.t()) :: {:ok, binary} | {:error, :not_found}
  def lookup(handler, address) do
    address_bin = Address.to_binary(address)

    case handler |> table_name() |> :ets.lookup(address_bin) do
      [] -> {:error, :not_found}
      [{_addr, dcid}] -> {:ok, dcid}
    end
  end

  @spec delete(module, Address.t()) :: :ok
  def delete(handler, address) do
    address_bin = Address.to_binary(address)
    handler |> table_name() |> :ets.delete(address_bin)
    :ok
  end

  defp table_name(handler),
    do: handler |> Module.concat(AddressTable) |> to_string() |> String.to_atom()
end
