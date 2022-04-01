defmodule Requiem.NIF do
  alias Requiem.Config

  @http3_alpn "h3"

  @spec init_config(module, integer) :: no_return
  def init_config(handler, ptr) do
    cert_chain = Config.get(handler, :cert_chain)

    if cert_chain != nil do
      if Requiem.NIF.Config.load_cert_chain_from_pem_file(ptr, cert_chain) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.load_cert_chain_from_pem_file failed"
      end
    else
      raise "<Requiem.NIF> :cert_chain must be set"
    end

    priv_key = Config.get(handler, :priv_key)

    if priv_key != nil do
      if Requiem.NIF.Config.load_priv_key_from_pem_file(ptr, priv_key) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.load_priv_key_from_pem_file failed"
      end
    else
      raise "<Requiem.NIF> :priv_key must be set"
    end

    verify_locations_file = Config.get(handler, :verify_locations_file)

    if verify_locations_file != nil do
      if Requiem.NIF.Config.load_verify_locations_from_file(ptr, verify_locations_file) !=
           :ok do
        raise "<Requiem.NIF> Requiem.NIF.load_verify_locations_from_file failed"
      end
    end

    verify_locations_dir = Config.get(handler, :verify_locations_directory)

    if verify_locations_dir != nil do
      if Requiem.NIF.Config.load_verify_locations_from_directory(ptr, verify_locations_dir) !=
           :ok do
        raise "<Requiem.NIF> Requiem.NIF.load_verify_locations_from_directory failed"
      end
    end

    verify_peer = Config.get(handler, :verify_peer)

    if verify_peer != nil do
      if Requiem.NIF.Config.verify_peer(ptr, verify_peer) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.verify_peer failed"
      end
    else
      # typically server doesn't 'verify_peer'
      if Requiem.NIF.Config.verify_peer(ptr, false) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.verify_peer failed"
      end
    end

    grease = Config.get(handler, :grease)

    if grease != nil do
      if Requiem.NIF.Config.grease(ptr, grease) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.grease failed"
      end
    end

    enable_early_data = Config.get(handler, :enable_early_data)

    if enable_early_data != nil && enable_early_data == true do
      if Requiem.NIF.Config.enable_early_data(ptr) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.enable_early_data failed"
      end
    end

    Requiem.NIF.Config.set_application_protos(ptr, [@http3_alpn])

    # default is inifinite
    max_idle_timeout = Config.get(handler, :max_idle_timeout)

    if max_idle_timeout != nil do
      if Requiem.NIF.Config.set_max_idle_timeout(ptr, max_idle_timeout) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.max_idle_timeout failed"
      end
    end

    # default is 65527
    max_udp_payload_size = Config.get(handler, :max_udp_payload_size)

    if max_udp_payload_size != nil do
      if Requiem.NIF.Config.set_max_udp_payload_size(ptr, max_udp_payload_size) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.max_udp_payload_size failed"
      end
    end

    # default is 0
    initial_max_data = Config.get(handler, :initial_max_data)

    if initial_max_data != nil do
      if Requiem.NIF.Config.set_initial_max_data(ptr, initial_max_data) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.initial_max_data failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_local = Config.get(handler, :initial_max_stream_data_bidi_local)

    if initial_max_stream_data_bidi_local != nil do
      if Requiem.NIF.Config.set_initial_max_stream_data_bidi_local(
           ptr,
           initial_max_stream_data_bidi_local
         ) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.initial_max_stream_data_bidi_local failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_remote =
      Config.get(handler, :initial_max_stream_data_bidi_remote)

    if initial_max_stream_data_bidi_remote != nil do
      if Requiem.NIF.Config.set_initial_max_stream_data_bidi_remote(
           ptr,
           initial_max_stream_data_bidi_remote
         ) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.initial_max_stream_data_bidi_remote failed"
      end
    end

    # default is 0
    initial_max_stream_data_uni = Config.get(handler, :initial_max_stream_data_uni)

    if initial_max_stream_data_uni != nil do
      if Requiem.NIF.Config.set_initial_max_stream_data_uni(ptr, initial_max_stream_data_uni) !=
           :ok do
        raise "<Requiem.NIF> Requiem.NIF.initial_max_stream_data_uni failed"
      end
    end

    # default is 0
    initial_max_streams_bidi = Config.get(handler, :initial_max_streams_bidi)

    if initial_max_streams_bidi != nil do
      if Requiem.NIF.Config.set_initial_max_streams_bidi(ptr, initial_max_streams_bidi) !=
           :ok do
        raise "<Requiem.NIF> Requiem.NIF.initial_max_streams_bidi failed"
      end
    end

    # default is 0
    initial_max_streams_uni = Config.get(handler, :initial_max_streams_uni)

    if initial_max_streams_uni != nil do
      if Requiem.NIF.Config.set_initial_max_streams_uni(ptr, initial_max_streams_uni) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.initial_max_streams_uni failed"
      end
    end

    if initial_max_streams_uni == nil || initial_max_streams_uni < 1 do
      raise "<Requiem.NIF> 'initial_max_streams_uni' must be greater than 0"
    end

    # default is 3
    ack_delay_exponent = Config.get(handler, :ack_delay_exponent)

    if ack_delay_exponent != nil do
      if Requiem.NIF.Config.set_ack_delay_exponent(ptr, ack_delay_exponent) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.ack_delay_exponent failed"
      end
    end

    # default is 25
    max_ack_delay = Config.get(handler, :max_ack_delay)

    if max_ack_delay != nil do
      if Requiem.NIF.Config.set_max_ack_delay(ptr, max_ack_delay) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.max_ack_delay failed"
      end
    end

    # default is false
    disable_active_migration = Config.get(handler, :disable_active_migration)

    if disable_active_migration != nil do
      if Requiem.NIF.Config.set_disable_active_migration(ptr, disable_active_migration) !=
           :ok do
        raise "<Requiem.NIF> Requiem.NIF.set_disable_active_migration failed"
      end
    end

    # default is "reno"
    cc_algorithm_name = Config.get(handler, :cc_algorithm_name)

    if cc_algorithm_name != nil do
      if Requiem.NIF.Config.set_cc_algorithm_name(ptr, cc_algorithm_name) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.set_cc_algorithm_name failed"
      end
    end

    # default is false
    enable_hystart = Config.get(handler, :enable_hystart)

    if enable_hystart != nil do
      if Requiem.NIF.Config.enable_hystart(ptr, enable_hystart) != :ok do
        raise "<Requiem.NIF> Requiem.NIF.enable_hystart failed"
      end
    end

    queue_size = Config.get(handler, :dgram_queue_size)

    if Requiem.NIF.Config.enable_dgram(ptr, true, queue_size, queue_size) != :ok do
      raise "<Requiem.NIF> Requiem.NIF.enable_dgram failed"
    end
  end
end
