defmodule RequiemTest.RetryTokenTest do
  use ExUnit.Case, async: true

  alias Requiem.Address
  alias Requiem.RetryToken
  alias Requiem.RetryToken.Protector
  alias Requiem.RetryToken.Params

  test "token protector" do
    origin = "HOGEHOGE"

    secret = :crypto.strong_rand_bytes(16)
    nonce = :crypto.strong_rand_bytes(16)

    {:ok, cipher, tag} = Protector.encrypt(secret, nonce, origin)
    {:ok, plain} = Protector.decrypt(secret, nonce, tag, cipher)

    assert origin == plain
    assert Protector.decrypt(secret, nonce, <<0xAA, 0xAA>>, cipher) == :error
    assert Protector.decrypt(<<0xAA, 0xAA>>, nonce, tag, cipher) == :error
    assert Protector.decrypt(secret, <<0xAA, 0xAA>>, tag, cipher) == :error
    assert Protector.decrypt(secret, nonce, tag, :crypto.strong_rand_bytes(40)) == :error
  end

  test "token params" do
    odcid = :crypto.strong_rand_bytes(16)
    scid = :crypto.strong_rand_bytes(16)

    addr1 = Address.new({192, 168, 0, 1}, 8080)
    encoded1 = Params.format(odcid, scid, addr1)
    {:ok, a_odcid1, a_scid1, a_addr1} = Params.parse(encoded1)
    assert a_odcid1 == odcid
    assert a_scid1 == scid
    assert Address.same?(addr1, a_addr1)

    addr2 = Address.new({0, 0, 0, 0, 0, 0, 0, 0}, 8080)
    encoded2 = Params.format(odcid, scid, addr2)
    {:ok, a_odcid2, a_scid2, a_addr2} = Params.parse(encoded2)
    assert a_odcid2 == odcid
    assert a_scid2 == scid
    assert Address.same?(addr2, a_addr2)

    random = :crypto.strong_rand_bytes(40)
    assert Params.parse(random) == :error
  end

  test "token validation" do
    odcid = :crypto.strong_rand_bytes(16)
    scid = :crypto.strong_rand_bytes(16)
    secret = :crypto.strong_rand_bytes(16)

    addr1 = Address.new({192, 168, 0, 1}, 8080)
    {:ok, rt1} = RetryToken.create(addr1, odcid, scid, secret)
    {:ok, a_odcid1} = RetryToken.validate(addr1, scid, secret, rt1)
    assert a_odcid1 == odcid
    scid2 = :crypto.strong_rand_bytes(16)
    assert RetryToken.validate(addr1, scid2, secret, rt1) == :error
  end
end
