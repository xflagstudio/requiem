defmodule RequiemTest.ConnectionTest do
  use ExUnit.Case, async: true

  alias Requiem.QUIC
  alias Requiem.QUIC.Connection

  test "connection NIF" do
    module = Module.concat(__MODULE__, Test1)

    scid = :crypto.strong_rand_bytes(20)
    odcid = :crypto.strong_rand_bytes(20)

    assert Connection.accept(module, scid, odcid) == {:error, :not_found}

    assert QUIC.init(module) == :ok

    {:ok, conn} = Connection.accept(module, scid, odcid)
    assert Connection.is_closed?(conn) == false
    assert Connection.close(conn, false, 0x1, "") == :ok
    assert Connection.is_closed?(conn) == true
  end

  test "multiple connection state" do
    module = Module.concat(__MODULE__, Test2)
    assert QUIC.init(module) == :ok

    scid1 = :crypto.strong_rand_bytes(20)
    odcid1 = :crypto.strong_rand_bytes(20)

    scid2 = :crypto.strong_rand_bytes(20)
    odcid2 = :crypto.strong_rand_bytes(20)

    {:ok, conn1} = Connection.accept(module, scid1, odcid1)
    {:ok, conn2} = Connection.accept(module, scid2, odcid2)
    assert Connection.is_closed?(conn1) == false
    assert Connection.is_closed?(conn2) == false
    assert Connection.close(conn1, false, 0x1, "") == :ok
    assert Connection.is_closed?(conn1) == true
    assert Connection.is_closed?(conn2) == false

    assert Connection.close(conn2, false, 0x1, "") == :ok

    assert Connection.is_closed?(conn1) == true
    assert Connection.is_closed?(conn2) == true

    # duplicated close command
    assert Connection.close(conn1, false, 0x1, "") == {:error, :already_closed}
    assert Connection.close(conn2, false, 0x1, "") == {:error, :already_closed}
  end
end
