defmodule RequiemTest.AddressTableTest do
  use ExUnit.Case, async: true

  alias Requiem.Address
  alias Requiem.AddressTable

  test "address table" do
    module1 = Module.concat(__MODULE__, Test1)
    module2 = Module.concat(__MODULE__, Test2)

    addr1 = Address.new({192, 168, 0, 1}, 80)
    addr2 = Address.new({0, 0, 0, 0, 0, 0, 0, 0}, 80)

    test_table_with_address(module1, addr1)
    test_table_with_address(module2, addr2)
  end

  defp test_table_with_address(module, addr) do
    assert_raise ArgumentError, fn ->
      AddressTable.lookup(module, addr) == {:error, :not_found}
    end

    AddressTable.init(module)
    assert AddressTable.lookup(module, addr) == {:error, :not_found}
    AddressTable.insert(module, addr, "abcde")
    assert AddressTable.lookup(module, addr) == {:ok, "abcde"}
    AddressTable.delete(module, addr)
    assert AddressTable.lookup(module, addr) == {:error, :not_found}
  end
end
