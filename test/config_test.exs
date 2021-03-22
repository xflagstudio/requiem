defmodule RequiemTest.ConfigTest do
  use ExUnit.Case, async: true

  alias Requiem.QUIC.Config

  test "call initialized config" do
    {:ok, c} = Config.new()

    try do
      assert Config.load_cert_chain_from_pem_file(c, "") == {:error, :system_error}
      assert Config.load_cert_chain_from_pem_file(c, "test/support/cert.crt") == :ok
      assert Config.load_priv_key_from_pem_file(c, "") == {:error, :system_error}
      assert Config.load_priv_key_from_pem_file(c, "test/support/cert.key") == :ok
      assert Config.load_verify_locations_from_file(c, "") == {:error, :system_error}
      assert Config.load_verify_locations_from_file(c, "test/support/rootca.crt") == :ok
      assert Config.load_verify_locations_from_directory(c, "") == {:error, :system_error}
      assert Config.verify_peer(c, true) == :ok
      assert Config.verify_peer(c, false) == :ok
      assert Config.grease(c, true) == :ok
      assert Config.grease(c, false) == :ok
      assert Config.enable_early_data(c) == :ok
      assert Config.set_application_protos(c, ["wq-vvv-01"]) == :ok
      assert Config.set_max_idle_timeout(c, 10000) == :ok
      assert Config.set_max_udp_payload_size(c, 1000) == :ok
      assert Config.set_initial_max_data(c, 1000) == :ok
      assert Config.set_initial_max_stream_data_bidi_local(c, 1000) == :ok
      assert Config.set_initial_max_stream_data_bidi_remote(c, 1000) == :ok
      assert Config.set_initial_max_stream_data_uni(c, 1000) == :ok
      assert Config.set_initial_max_streams_bidi(c, 1000) == :ok
      assert Config.set_initial_max_streams_uni(c, 1000) == :ok
      assert Config.set_ack_delay_exponent(c, 1000) == :ok
      assert Config.set_disable_active_migration(c, true) == :ok
      assert Config.set_disable_active_migration(c, false) == :ok
      assert Config.set_cc_algorithm_name(c, "") == {:error, :system_error}
      assert Config.set_cc_algorithm_name(c, "reno") == :ok
      assert Config.enable_hystart(c, true) == :ok
      assert Config.enable_hystart(c, false) == :ok
      assert Config.enable_dgram(c, true, 100, 100) == :ok
      assert Config.enable_dgram(c, false, 100, 100) == :ok
    after
      Config.destroy(c)
    end
  end

  test "ALPN param" do
    assert Requiem.QUIC.Config.ALPN.encode("http/1.1") ==
             <<0x08, 0x68, 0x74, 0x74, 0x70, 0x2F, 0x31, 0x2E, 0x31>>

    assert Requiem.QUIC.Config.ALPN.encode_list(["http/1.0", "http/1.1"]) ==
             <<0x08, 0x68, 0x74, 0x74, 0x70, 0x2F, 0x31, 0x2E, 0x30, 0x08, 0x68, 0x74, 0x74, 0x70,
               0x2F, 0x31, 0x2E, 0x31>>
  end

  test "config typo" do
    opts1 = [enable_dgram: true]
    assert Requiem.Config.check_key_existence(opts1) == :ok
    opts2 = [enable_datagram: true]

    assert_raise RuntimeError, fn ->
      Requiem.Config.check_key_existence(opts2)
    end
  end
end
