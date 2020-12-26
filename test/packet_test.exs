defmodule RequiemTest.PacketTest do
  use ExUnit.Case, async: true

  alias Requiem.QUIC.Packet

  test "parse initial packet" do
    expected_odcid = <<0x83, 0x94, 0xC8, 0xF0, 0x3E, 0x51, 0x57, 0x08>>

    packet =
      <<0xC3, 0xFF, 0x00, 0x00, 0x1D, 0x08, 0x83, 0x94, 0xC8, 0xF0, 0x3E, 0x51, 0x57, 0x08, 0x00,
        0x00, 0x44, 0x9E, 0x00, 0x00, 0x00, 0x02>>

    {:ok, scid, dcid, token, _version, typ, matched_version} = Packet.parse_header(packet)

    assert scid == <<>>
    assert dcid == expected_odcid
    assert token == <<>>
    assert typ == :initial
    assert matched_version == true
  end
end
