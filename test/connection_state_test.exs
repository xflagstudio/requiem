defmodule RequiemTest.ConnectionStateTest do
  use ExUnit.Case, async: true

  alias Requiem.ConnectionState
  alias Requiem.Address
  alias Requiem.QUIC.StreamId

  test "connection state's stream_id" do
    addr = Address.new({192, 168, 0, 1}, 8080)
    scid = :crypto.strong_rand_bytes(20)
    dcid = :crypto.strong_rand_bytes(20)
    odcid = :crypto.strong_rand_bytes(20)

    state = ConnectionState.new(addr, dcid, scid, odcid)

    {id1, state1} = ConnectionState.create_new_stream_id(state, :bidi)
    assert StreamId.is_server_initiated(id1)
    assert StreamId.is_bidi(id1)
    assert !StreamId.is_uni(id1)

    {id2, state2} = ConnectionState.create_new_stream_id(state1, :bidi)
    assert StreamId.is_server_initiated(id2)
    assert StreamId.is_bidi(id2)
    assert !StreamId.is_uni(id2)

    {id3, state3} = ConnectionState.create_new_stream_id(state2, :uni)
    assert StreamId.is_server_initiated(id3)
    assert !StreamId.is_bidi(id3)
    assert StreamId.is_uni(id3)

    assert state3.stream_id_pod == 3
  end

  test "connection state trapping_id" do
    addr = Address.new({192, 168, 0, 1}, 8080)
    scid = :crypto.strong_rand_bytes(20)
    dcid = :crypto.strong_rand_bytes(20)
    odcid = :crypto.strong_rand_bytes(20)

    state = ConnectionState.new(addr, dcid, scid, odcid)

    assert ConnectionState.should_delegate_exit?(state, self()) == false
    state2 = ConnectionState.trap_exit(state, self())
    assert ConnectionState.should_delegate_exit?(state2, self()) == true
    state3 = ConnectionState.forget_to_trap_exit(state2, self())
    assert ConnectionState.should_delegate_exit?(state3, self()) == false
  end
end
