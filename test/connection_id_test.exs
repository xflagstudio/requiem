defmodule RequiemTest.ConnectionIDTest do
  use ExUnit.Case, async: true

  alias Requiem.QUIC.ConnectionID

  test "connection id" do
    key = :crypto.strong_rand_bytes(32)

    odcid1 = :crypto.strong_rand_bytes(10)
    odcid2 = :crypto.strong_rand_bytes(20)

    {:ok, newid1} = ConnectionID.generate_from_odcid(key, odcid1)
    {:ok, newid2} = ConnectionID.generate_from_odcid(key, odcid2)

    assert byte_size(newid1) == 20
    assert byte_size(newid2) == 20
  end
end
