defmodule Requiem.QUIC do
  alias Requiem.Config
  alias Requiem.QUIC.NIF

  @web_transport_alpn "wq-vvv-01"

  @spec setup(module) ::
          :ok | {:error, :system_error}
  def setup(handler) do
    stream_buffer_pool_size = Config.get(handler, :stream_buffer_pool_size)
    stream_buffer_size = [
      Config.get(handler, :initial_max_stream_data_bidi_local),
      Config.get(handler, :initial_max_stream_data_uni),
      100_000
    ] |> Enum.max()

    case init(handler, stream_buffer_pool_size, stream_buffer_size) do
      :ok ->
        init_config(handler)
        :ok

      {:error, :system_error} ->
        {:error, :system_error}
    end
  end

  @spec init(module) :: :ok | {:error, :system_error}
  def init(handler, stream_buffer_pool_size \\ 10, stream_buffer_size \\ 8092) do
    handler
    |> to_string()
    |> NIF.quic_init(stream_buffer_pool_size, stream_buffer_size)
  end

  defp init_config(handler) do
    is_web_transport = Config.get(handler, :web_transport)

    cert_chain = Config.get(handler, :cert_chain)

    if cert_chain != nil do
      if Requiem.QUIC.Config.load_cert_chain_from_pem_file(handler, cert_chain) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.load_cert_chain_from_pem_file failed"
      end
    else
      raise "<Requiem.QUIC> :cert_chain must be set"
    end

    priv_key = Config.get(handler, :priv_key)

    if priv_key != nil do
      if Requiem.QUIC.Config.load_priv_key_from_pem_file(handler, priv_key) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.load_priv_key_from_pem_file failed"
      end
    else
      raise "<Requiem.QUIC> :priv_key must be set"
    end

    verify_locations_file = Config.get(handler, :verify_locations_file)

    if verify_locations_file != nil do
      if Requiem.QUIC.Config.load_verify_locations_from_file(handler, verify_locations_file) !=
           :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.load_verify_locations_from_file failed"
      end
    end

    verify_locations_dir = Config.get(handler, :verify_locations_directory)

    if verify_locations_dir != nil do
      if Requiem.QUIC.Config.load_verify_locations_from_directory(handler, verify_locations_dir) !=
           :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.load_verify_locations_from_directory failed"
      end
    end

    verify_peer = Config.get(handler, :verify_peer)

    if verify_peer != nil do
      if Requiem.QUIC.Config.verify_peer(handler, verify_peer) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.verify_peer failed"
      end
    else
      # typically server doesn't 'verify_peer'
      if Requiem.QUIC.Config.verify_peer(handler, false) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.verify_peer failed"
      end
    end

    grease = Config.get(handler, :grease)

    if grease != nil do
      if Requiem.QUIC.Config.grease(handler, grease) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.grease failed"
      end
    end

    enable_early_data = Config.get(handler, :enable_early_data)

    if enable_early_data != nil && enable_early_data == true do
      if Requiem.QUIC.Config.enable_early_data(handler) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.enable_early_data failed"
      end
    end

    if is_web_transport do
      Requiem.QUIC.Config.set_application_protos(handler, [@web_transport_alpn])
    else
      application_protos = Config.get(handler, :application_protos)

      if application_protos != nil do
        if Requiem.QUIC.Config.set_application_protos(handler, application_protos) != :ok do
          raise "<Requiem.QUIC> Requiem.QUIC.application_protos failed"
        end
      end
    end

    # default is inifinite
    max_idle_timeout = Config.get(handler, :max_idle_timeout)

    if max_idle_timeout != nil do
      if Requiem.QUIC.Config.set_max_idle_timeout(handler, max_idle_timeout) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.max_idle_timeout failed"
      end
    end

    # default is 65527
    max_udp_payload_size = Config.get(handler, :max_udp_payload_size)

    if max_udp_payload_size != nil do
      if Requiem.QUIC.Config.set_max_udp_payload_size(handler, max_udp_payload_size) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.max_udp_payload_size failed"
      end
    end

    # default is 0
    initial_max_data = Config.get(handler, :initial_max_data)

    if initial_max_data != nil do
      if Requiem.QUIC.Config.set_initial_max_data(handler, initial_max_data) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.initial_max_data failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_local = Config.get(handler, :initial_max_stream_data_bidi_local)

    if initial_max_stream_data_bidi_local != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_bidi_local(
           handler,
           initial_max_stream_data_bidi_local
         ) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.initial_max_stream_data_bidi_local failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_remote =
      Config.get(handler, :initial_max_stream_data_bidi_remote)

    if initial_max_stream_data_bidi_remote != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_bidi_remote(
           handler,
           initial_max_stream_data_bidi_remote
         ) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.initial_max_stream_data_bidi_remote failed"
      end
    end

    # default is 0
    initial_max_stream_data_uni = Config.get(handler, :initial_max_stream_data_uni)

    if initial_max_stream_data_uni != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_uni(handler, initial_max_stream_data_uni) !=
           :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.initial_max_stream_data_uni failed"
      end
    end

    # default is 0
    initial_max_streams_bidi = Config.get(handler, :initial_max_streams_bidi)

    if initial_max_streams_bidi != nil do
      if Requiem.QUIC.Config.set_initial_max_streams_bidi(handler, initial_max_streams_bidi) !=
           :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.initial_max_streams_bidi failed"
      end
    end

    # default is 0
    initial_max_streams_uni = Config.get(handler, :initial_max_streams_uni)

    if initial_max_streams_uni != nil do
      if Requiem.QUIC.Config.set_initial_max_streams_uni(handler, initial_max_streams_uni) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.initial_max_streams_uni failed"
      end
    end

    if is_web_transport do
      if initial_max_streams_uni == nil || initial_max_streams_uni < 1 do
        raise "<Requiem.QUIC> on WebTransport mode, 'initial_max_streams_uni' must be greater than 0"
      end
    end

    # default is 3
    ack_delay_exponent = Config.get(handler, :ack_delay_exponent)

    if ack_delay_exponent != nil do
      if Requiem.QUIC.Config.set_ack_delay_exponent(handler, ack_delay_exponent) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.ack_delay_exponent failed"
      end
    end

    # default is 25
    max_ack_delay = Config.get(handler, :max_ack_delay)

    if max_ack_delay != nil do
      if Requiem.QUIC.Config.set_max_ack_delay(handler, max_ack_delay) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.max_ack_delay failed"
      end
    end

    # default is false
    disable_active_migration = Config.get(handler, :disable_active_migration)

    if disable_active_migration != nil do
      if Requiem.QUIC.Config.set_disable_active_migration(handler, disable_active_migration) !=
           :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.set_disable_active_migration failed"
      end
    end

    # default is "reno"
    cc_algorithm_name = Config.get(handler, :cc_algorithm_name)

    if cc_algorithm_name != nil do
      if Requiem.QUIC.Config.set_cc_algorithm_name(handler, cc_algorithm_name) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.set_cc_algorithm_name failed"
      end
    end

    # default is false
    enable_hystart = Config.get(handler, :enable_hystart)

    if enable_hystart != nil do
      if Requiem.QUIC.Config.enable_hystart(handler, enable_hystart) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.enable_hystart failed"
      end
    end

    # default is false
    enable_dgram = Config.get(handler, :enable_dgram)

    if enable_dgram != nil do
      queue_size = Config.get(handler, :dgram_queue_size)

      if Requiem.QUIC.Config.enable_dgram(handler, enable_dgram, queue_size, queue_size) != :ok do
        raise "<Requiem.QUIC> Requiem.QUIC.enable_dgram failed"
      end
    end
  end
end
