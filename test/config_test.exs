defmodule RequiemTest.ConfigTest do
  use ExUnit.Case, async: true

  alias Requiem.QUIC
  alias Requiem.QUIC.Config

  test "call initialized config" do
    module = Module.concat(__MODULE__, Test1)
    assert QUIC.init(module) == :ok
    # test Config.on
    assert QUIC.init(module) == :ok
    assert Config.load_cert_chain_from_pem_file(module, "") == {:error, :system_error}
    assert Config.load_cert_chain_from_pem_file(module, "test/support/cert.crt") == :ok
    assert Config.load_priv_key_from_pem_file(module, "") == {:error, :system_error}
    assert Config.load_priv_key_from_pem_file(module, "test/support/cert.key") == :ok
    assert Config.load_verify_locations_from_file(module, "") == {:error, :system_error}
    assert Config.load_verify_locations_from_file(module, "test/support/rootca.crt") == :ok
    assert Config.load_verify_locations_from_directory(module, "") == {:error, :system_error}
    assert Config.verify_peer(module, true) == :ok
    assert Config.verify_peer(module, false) == :ok
    assert Config.grease(module, true) == :ok
    assert Config.grease(module, false) == :ok
    assert Config.enable_early_data(module) == :ok
    assert Config.set_application_protos(module, ["wq-vvv-01"]) == :ok
    assert Config.set_max_idle_timeout(module, 10000) == :ok
    assert Config.set_max_udp_payload_size(module, 1000) == :ok
    assert Config.set_initial_max_data(module, 1000) == :ok
    assert Config.set_initial_max_stream_data_bidi_local(module, 1000) == :ok
    assert Config.set_initial_max_stream_data_bidi_remote(module, 1000) == :ok
    assert Config.set_initial_max_stream_data_uni(module, 1000) == :ok
    assert Config.set_initial_max_streams_bidi(module, 1000) == :ok
    assert Config.set_initial_max_streams_uni(module, 1000) == :ok
    assert Config.set_ack_delay_exponent(module, 1000) == :ok
    assert Config.set_disable_active_migration(module, true) == :ok
    assert Config.set_disable_active_migration(module, false) == :ok
    assert Config.set_cc_algorithm_name(module, "") == {:error, :system_error}
    assert Config.set_cc_algorithm_name(module, "reno") == :ok
    assert Config.enable_hystart(module, true) == :ok
    assert Config.enable_hystart(module, false) == :ok
    assert Config.enable_dgram(module, true, 100, 100) == :ok
    assert Config.enable_dgram(module, false, 100, 100) == :ok
  end

  test "call not-initialized config" do
    module = Module.concat(__MODULE__, Test2)
    assert Config.load_cert_chain_from_pem_file(module, "") == {:error, :not_found}
    assert Config.load_priv_key_from_pem_file(module, "") == {:error, :not_found}
    assert Config.load_verify_locations_from_file(module, "") == {:error, :not_found}
    assert Config.load_verify_locations_from_directory(module, "") == {:error, :not_found}
    assert Config.verify_peer(module, true) == {:error, :not_found}
    assert Config.verify_peer(module, false) == {:error, :not_found}
    assert Config.grease(module, true) == {:error, :not_found}
    assert Config.grease(module, false) == {:error, :not_found}
    assert Config.enable_early_data(module) == {:error, :not_found}
    assert Config.set_application_protos(module, ["wq-vvv-01"]) == {:error, :not_found}
    assert Config.set_max_idle_timeout(module, 10000) == {:error, :not_found}
    assert Config.set_max_udp_payload_size(module, 1000) == {:error, :not_found}
    assert Config.set_initial_max_data(module, 1000) == {:error, :not_found}
    assert Config.set_initial_max_stream_data_bidi_local(module, 1000) == {:error, :not_found}
    assert Config.set_initial_max_stream_data_bidi_remote(module, 1000) == {:error, :not_found}
    assert Config.set_initial_max_stream_data_uni(module, 1000) == {:error, :not_found}
    assert Config.set_initial_max_streams_bidi(module, 1000) == {:error, :not_found}
    assert Config.set_initial_max_streams_uni(module, 1000) == {:error, :not_found}
    assert Config.set_ack_delay_exponent(module, 1000) == {:error, :not_found}
    assert Config.set_disable_active_migration(module, true) == {:error, :not_found}
    assert Config.set_disable_active_migration(module, false) == {:error, :not_found}
    assert Config.set_cc_algorithm_name(module, "") == {:error, :not_found}
    assert Config.enable_hystart(module, true) == {:error, :not_found}
    assert Config.enable_hystart(module, false) == {:error, :not_found}
    assert Config.enable_dgram(module, true, 100, 100) == {:error, :not_found}
    assert Config.enable_dgram(module, false, 100, 100) == {:error, :not_found}
  end

  defmodule ConfigTestTask do
    def execute(module) do
      assert Config.enable_dgram(module, true, 100, 100) == :ok
    end
  end

  test "call config from multiple process" do
    module = Module.concat(__MODULE__, Test3)
    assert QUIC.init(module) == :ok
    task = Task.async(ConfigTestTask, :execute, [module])
    Task.await(task)
    assert Config.enable_dgram(module, false, 100, 100) == :ok
  end

  test "ALPN param" do
    assert Requiem.QUIC.Config.ALPN.encode("http/1.1") ==
             <<0x08, 0x68, 0x74, 0x74, 0x70, 0x2F, 0x31, 0x2E, 0x31>>

    assert Requiem.QUIC.Config.ALPN.encode_list(["http/1.0", "http/1.1"]) ==
             <<0x08, 0x68, 0x74, 0x74, 0x70, 0x2F, 0x31, 0x2E, 0x30, 0x08, 0x68, 0x74, 0x74, 0x70,
               0x2F, 0x31, 0x2E, 0x31>>
  end
end
