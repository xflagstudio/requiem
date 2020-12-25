defmodule RequiemTest.AddressTest do
  use ExUnit.Case, async: true

  alias Requiem.Address

  test "address " do
    addr1 = Address.new({192, 168, 0, 1}, 80)
    addr2 = Address.new({192, 168, 0, 1}, 443)

    addr3 = Address.new({0, 0, 0, 0, 0, 0, 0, 0}, 80)
    addr4 = Address.new({0, 0, 0, 0, 0, 0, 0, 0}, 443)

    b1 = Address.to_binary(addr1)
    {:ok, result1} = Address.from_binary(b1)
    assert result1.host == {192, 168, 0, 1}
    assert result1.port == 80

    b2 = Address.to_binary(addr2)
    {:ok, result2} = Address.from_binary(b2)
    assert result2.host == result1.host
    assert result2.port != result1.port
    assert result2.port == 443

    b3 = Address.to_binary(addr3)
    {:ok, result3} = Address.from_binary(b3)
    assert result3.host == {0, 0, 0, 0, 0, 0, 0, 0}
    assert result3.port == 80

    b4 = Address.to_binary(addr4)
    {:ok, result4} = Address.from_binary(b4)
    assert result4.host == {0, 0, 0, 0, 0, 0, 0, 0}
    assert result4.port == 443
  end
end
