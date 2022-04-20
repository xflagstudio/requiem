defmodule RequiemTest.ConnectionTest do
  use ExUnit.Case, async: true

  alias Requiem.NIF.Config
  alias Requiem.NIF.Socket
  alias Requiem.NIF.Connection

  defmodule TestSender do
    use GenServer

    def start_link() do
      GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    end

    def init(_opts) do
      {:ok, %{}}
    end

    def handle_info({:__drain__, _peer, _packet}, _state) do
    end
  end

  test "connection NIF" do
    {:ok, sender_pid} = TestSender.start_link()

    scid = :crypto.strong_rand_bytes(20)
    odcid = :crypto.strong_rand_bytes(20)

    {:ok, peer} = Socket.address_from_string("192.168.0.1:4000")
    {:ok, c} = Config.new()

    try do
      {:ok, conn} = Connection.accept(c, scid, odcid, peer, sender_pid, 1024 * 10)

      try do
        assert Connection.is_closed?(conn) == false
        assert Connection.close(conn, false, 0x1, "") == {:error, :already_closed}
        assert Connection.is_closed?(conn) == true
      after
        Connection.destroy(conn)
      end
    after
      Config.destroy(c)
      Process.exit(sender_pid, :kill)
    end
  end

  test "multiple connection state" do
    scid1 = :crypto.strong_rand_bytes(20)
    odcid1 = :crypto.strong_rand_bytes(20)

    scid2 = :crypto.strong_rand_bytes(20)
    odcid2 = :crypto.strong_rand_bytes(20)

    {:ok, peer} = Socket.address_from_string("192.168.0.1:4000")

    {:ok, sender_pid} = TestSender.start_link()
    {:ok, c} = Config.new()

    try do
      {:ok, conn1} = Connection.accept(c, scid1, odcid1, peer, sender_pid, 1024 * 10)
      {:ok, conn2} = Connection.accept(c, scid2, odcid2, peer, sender_pid, 1024 * 10)

      try do
        assert Connection.is_closed?(conn1) == false
        assert Connection.is_closed?(conn2) == false
        assert Connection.close(conn1, false, 0x1, "") == {:error, :already_closed}
        assert Connection.is_closed?(conn1) == true
        assert Connection.is_closed?(conn2) == false

        assert Connection.close(conn2, false, 0x1, "") == {:error, :already_closed}

        assert Connection.is_closed?(conn1) == true
        assert Connection.is_closed?(conn2) == true

        # duplicated close command
        assert Connection.close(conn1, false, 0x1, "") == {:error, :already_closed}
        assert Connection.close(conn2, false, 0x1, "") == {:error, :already_closed}
      after
        Connection.destroy(conn1)
        Connection.destroy(conn2)
      end
    after
      Config.destroy(c)
      Process.exit(sender_pid, :kill)
    end
  end
end
