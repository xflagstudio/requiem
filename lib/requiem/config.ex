defmodule Requiem.Config do
  @moduledoc """
  Config helper module
  """

  @web_transport_alpn "wq-vvv-01"

  @type config_key ::
          :web_transport
          | :port
          | :loggable
          | :sender_buffering_interval
          | :sender_pool_size
          | :sender_pool_max_overflow
          | :dispatcher_pool_size
          | :dispatcher_pool_max_overflow
          | :quic_token_secret
          | :quic_connection_id_secret
          | :quic_dgram_queue_size
          | :quic_cert_chain
          | :quic_priv_key
          | :quic_verify_locations_file
          | :quic_verify_locations_directory
          | :quic_grease
          | :quic_verify_peer
          | :quic_enable_early_data
          | :quic_application_protos
          | :quic_max_idle_timeout
          | :quic_max_udp_payload_size
          | :quic_initial_max_data
          | :quic_initial_max_stream_data_bidi_local
          | :quic_initial_max_stream_data_bidi_remote
          | :quic_initial_max_stream_data_uni
          | :quic_initial_max_streams_bidi
          | :quic_initial_max_streams_uni
          | :quic_ack_delay_exponent
          | :quic_max_ack_delay
          | :quic_disable_active_migration
          | :quic_cc_algorithm_name
          | :quic_enable_hystart
          | :quic_enable_dgram

  @default_values [
    web_transport: true,
    port: 443,
    loggable: false,
    sender_buffering_interval: 0,
    sender_pool_size: 10,
    sender_pool_max_overflow: 0,
    dispatcher_pool_size: 10,
    dispatcher_pool_max_overflow: 0,
    quic_token_secret: :crypto.strong_rand_bytes(16),
    quic_connection_id_secret: :crypto.strong_rand_bytes(32),
    quic_dgram_queue_size: 1000
  ]

  @spec get!(module, config_key) :: term
  def get!(handler, key) do
    case handler |> config_name() |> FastGlobal.get(nil) do
      nil ->
        raise "<Requiem.Config> config not saved for #{handler}, maybe Requiem.Supervisor has not completed setup"

      conf ->
        Keyword.fetch!(conf, key)
    end
  end

  @spec get(module, config_key) :: term | nil
  def get(handler, key) do
    case handler |> config_name() |> FastGlobal.get(nil) do
      nil ->
        raise "<Requiem.Config> config not saved for #{handler}, maybe Requiem.Supervisor has not completed setup"

      conf ->
        Keyword.get(conf, key, nil)
    end
  end

  @spec setup(module, atom) :: :ok
  def setup(handler, otp_app) do
    config1 = Application.get_env(otp_app, handler, [])
    config2 = Keyword.merge(@default_values, config1)
    store(handler, config2)
    setup_quiche(handler)
  end

  @spec store(module, Keyword.t()) :: :ok
  def store(handler, val) do
    handler |> config_name() |> FastGlobal.put(val)
    :ok
  end

  defp setup_quiche(handler) do
    is_web_transport = get(handler, :web_transport)

    cert_chain = get(handler, :quic_cert_chain)

    if cert_chain != nil do
      if Requiem.QUIC.Config.load_cert_chain_from_pem_file(handler, cert_chain) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_cert_chain_from_pem_file failed"
      end
    else
      raise "<Requiem.Config> :quic_cert_chain must be set"
    end

    priv_key = get(handler, :quic_priv_key)

    if priv_key != nil do
      if Requiem.QUIC.Config.load_priv_key_from_pem_file(handler, priv_key) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_priv_key_from_pem_file failed"
      end
    else
      raise "<Requiem.Config> :quic_priv_key must be set"
    end

    verify_locations_file = get(handler, :quic_verify_locations_file)

    if verify_locations_file != nil do
      if Requiem.QUIC.Config.load_verify_locations_from_file(handler, verify_locations_file) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_verify_locations_from_file failed"
      end
    end

    verify_locations_dir = get(handler, :quic_verify_locations_directory)

    if verify_locations_dir != nil do
      if Requiem.QUIC.Config.load_verify_locations_from_directory(handler, verify_locations_dir) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_verify_locations_from_directory failed"
      end
    end

    verify_peer = get(handler, :quic_verify_peer)

    if verify_peer != nil do
      if Requiem.QUIC.Config.verify_peer(handler, verify_peer) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.verify_peer failed"
      end
    else
      # typically server doesn't 'verify_peer'
      if Requiem.QUIC.Config.verify_peer(handler, false) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.verify_peer failed"
      end
    end

    grease = get(handler, :quic_grease)

    if grease != nil do
      if Requiem.QUIC.Config.grease(handler, grease) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.grease failed"
      end
    end

    enable_early_data = get(handler, :quic_enable_early_data)

    if enable_early_data != nil && enable_early_data == true do
      if Requiem.QUIC.Config.enable_early_data(handler) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.enable_early_data failed"
      end
    end

    if is_web_transport do
      Requiem.QUIC.Config.set_application_protos(handler, [@web_transport_alpn])
    else
      application_protos = get(handler, :quic_application_protos)

      if application_protos != nil do
        if Requiem.QUIC.Config.set_application_protos(handler, application_protos) != :ok do
          raise "<Requiem.Config> Requiem.QUIC.application_protos failed"
        end
      end
    end

    # default is inifinite
    max_idle_timeout = get(handler, :quic_max_idle_timeout)

    if max_idle_timeout != nil do
      if Requiem.QUIC.Config.set_max_idle_timeout(handler, max_idle_timeout) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.max_idle_timeout failed"
      end
    end

    # default is 65527
    max_udp_payload_size = get(handler, :quic_max_udp_payload_size)

    if max_udp_payload_size != nil do
      if Requiem.QUIC.Config.set_max_udp_payload_size(handler, max_udp_payload_size) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.max_udp_payload_size failed"
      end
    end

    # default is 0
    initial_max_data = get(handler, :quic_initial_max_data)

    if initial_max_data != nil do
      if Requiem.QUIC.Config.set_initial_max_data(handler, initial_max_data) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_data failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_local = get(handler, :quic_initial_max_stream_data_bidi_local)

    if initial_max_stream_data_bidi_local != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_bidi_local(
           handler,
           initial_max_stream_data_bidi_local
         ) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_stream_data_bidi_local failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_remote = get(handler, :quic_initial_max_stream_data_bidi_remote)

    if initial_max_stream_data_bidi_remote != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_bidi_remote(
           handler,
           initial_max_stream_data_bidi_remote
         ) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_stream_data_bidi_remote failed"
      end
    end

    # default is 0
    initial_max_stream_data_uni = get(handler, :quic_initial_max_stream_data_uni)

    if initial_max_stream_data_uni != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_uni(handler, initial_max_stream_data_uni) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_stream_data_uni failed"
      end
    end

    # default is 0
    initial_max_streams_bidi = get(handler, :quic_initial_max_streams_bidi)

    if initial_max_streams_bidi != nil do
      if Requiem.QUIC.Config.set_initial_max_streams_bidi(handler, initial_max_streams_bidi) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_streams_bidi failed"
      end
    end

    # default is 0
    initial_max_streams_uni = get(handler, :quic_initial_max_streams_uni)

    if initial_max_streams_uni != nil do
      if Requiem.QUIC.Config.set_initial_max_streams_uni(handler, initial_max_streams_uni) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_streams_uni failed"
      end
    end

    if is_web_transport do
      if initial_max_streams_uni == nil || initial_max_streams_uni < 1 do
        raise "<Requiem.Config> on WebTransport mode, 'initial_max_streams_uni' must be greater than 0"
      end
    end

    # default is 3
    ack_delay_exponent = get(handler, :quic_ack_delay_exponent)

    if ack_delay_exponent != nil do
      if Requiem.QUIC.Config.set_ack_delay_exponent(handler, ack_delay_exponent) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.ack_delay_exponent failed"
      end
    end

    # default is 25
    max_ack_delay = get(handler, :quic_max_ack_delay)

    if max_ack_delay != nil do
      if Requiem.QUIC.Config.set_max_ack_delay(handler, max_ack_delay) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.max_ack_delay failed"
      end
    end

    # default is false
    disable_active_migration = get(handler, :quic_disable_active_migration)

    if disable_active_migration != nil do
      if Requiem.QUIC.Config.set_disable_active_migration(handler, disable_active_migration) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.set_disable_active_migration failed"
      end
    end

    # default is "reno"
    cc_algorithm_name = get(handler, :quic_cc_algorithm_name)

    if cc_algorithm_name != nil do
      if Requiem.QUIC.Config.set_cc_algorithm_name(handler, cc_algorithm_name) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.set_cc_algorithm_name failed"
      end
    end

    # default is false
    enable_hystart = get(handler, :quic_enable_hystart)

    if enable_hystart != nil do
      if Requiem.QUIC.Config.enable_hystart(handler, enable_hystart) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.enable_hystart failed"
      end
    end

    # default is false
    enable_dgram = get(handler, :quic_enable_dgram)

    if enable_dgram != nil do
      queue_size = get(handler, :quic_dgram_queue_size)

      if Requiem.QUIC.Config.enable_dgram(handler, enable_dgram, queue_size, queue_size) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.enable_dgram failed"
      end
    end
  end

  defp config_name(handler), do: Module.concat(handler, __MODULE__)
end
