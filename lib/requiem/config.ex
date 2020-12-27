defmodule Requiem.Config do
  @moduledoc """
  Config helper module
  """

  @web_transport_alpn "wq-vvv-01"

  @type config_key ::
          :web_transport
          | :port
          | :trace
          | :sender_buffering_interval
          | :sender_pool_size
          | :sender_pool_max_overflow
          | :dispatcher_pool_size
          | :dispatcher_pool_max_overflow
          | :token_secret
          | :connection_id_secret
          | :dgram_queue_size
          | :cert_chain
          | :priv_key
          | :verify_locations_file
          | :verify_locations_directory
          | :grease
          | :verify_peer
          | :enable_early_data
          | :application_protos
          | :max_idle_timeout
          | :max_udp_payload_size
          | :initial_max_data
          | :initial_max_stream_data_bidi_local
          | :initial_max_stream_data_bidi_remote
          | :initial_max_stream_data_uni
          | :initial_max_streams_bidi
          | :initial_max_streams_uni
          | :ack_delay_exponent
          | :max_ack_delay
          | :disable_active_migration
          | :cc_algorithm_name
          | :enable_hystart
          | :enable_dgram

  @default_values [
    web_transport: true,
    port: 443,
    trace: false,
    sender_buffering_interval: 0,
    sender_pool_size: 10,
    sender_pool_max_overflow: 0,
    dispatcher_pool_size: 10,
    dispatcher_pool_max_overflow: 0,
    token_secret: :crypto.strong_rand_bytes(16),
    connection_id_secret: :crypto.strong_rand_bytes(32),
    dgram_queue_size: 1000,
    max_idle_timeout: 60_000
  ]

  @key_table %{
    web_transport: true,
    port: true,
    trace: true,
    sender_buffering_interval: true,
    sender_pool_size: true,
    sender_pool_max_overflow: true,
    dispatcher_pool_size: true,
    dispatcher_pool_max_overflow: true,
    token_secret: true,
    connection_id_secret: true,
    dgram_queue_size: true,
    cert_chain: true,
    priv_key: true,
    verify_locations_file: true,
    verify_locations_directory: true,
    grease: true,
    verify_peer: true,
    enable_early_data: true,
    application_protos: true,
    max_idle_timeout: true,
    max_udp_payload_size: true,
    initial_max_data: true,
    initial_max_stream_data_bidi_local: true,
    initial_max_stream_data_bidi_remote: true,
    initial_max_stream_data_uni: true,
    initial_max_streams_bidi: true,
    initial_max_streams_uni: true,
    ack_delay_exponent: true,
    max_ack_delay: true,
    disable_active_migration: true,
    cc_algorithm_name: true,
    enable_hystart: true,
    enable_dgram: true
  }

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
    check_key_existence(config2)
    store(handler, config2)
    setup_quiche(handler)
  end

  @spec store(module, Keyword.t()) :: :ok
  def store(handler, val) do
    handler |> config_name() |> FastGlobal.put(val)
    :ok
  end

  @spec check_key_existence(Keyword.t()) :: :ok
  def check_key_existence(opts) do
    Enum.each(opts, fn {k, _v} ->
      if !Map.has_key?(@key_table, k) do
        raise "<Requiem.Config> unknown key:#{k} set."
      end
    end)
  end

  defp setup_quiche(handler) do
    is_web_transport = get(handler, :web_transport)

    cert_chain = get(handler, :cert_chain)

    if cert_chain != nil do
      if Requiem.QUIC.Config.load_cert_chain_from_pem_file(handler, cert_chain) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_cert_chain_from_pem_file failed"
      end
    else
      raise "<Requiem.Config> :cert_chain must be set"
    end

    priv_key = get(handler, :priv_key)

    if priv_key != nil do
      if Requiem.QUIC.Config.load_priv_key_from_pem_file(handler, priv_key) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_priv_key_from_pem_file failed"
      end
    else
      raise "<Requiem.Config> :priv_key must be set"
    end

    verify_locations_file = get(handler, :verify_locations_file)

    if verify_locations_file != nil do
      if Requiem.QUIC.Config.load_verify_locations_from_file(handler, verify_locations_file) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_verify_locations_from_file failed"
      end
    end

    verify_locations_dir = get(handler, :verify_locations_directory)

    if verify_locations_dir != nil do
      if Requiem.QUIC.Config.load_verify_locations_from_directory(handler, verify_locations_dir) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.load_verify_locations_from_directory failed"
      end
    end

    verify_peer = get(handler, :verify_peer)

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

    grease = get(handler, :grease)

    if grease != nil do
      if Requiem.QUIC.Config.grease(handler, grease) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.grease failed"
      end
    end

    enable_early_data = get(handler, :enable_early_data)

    if enable_early_data != nil && enable_early_data == true do
      if Requiem.QUIC.Config.enable_early_data(handler) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.enable_early_data failed"
      end
    end

    if is_web_transport do
      Requiem.QUIC.Config.set_application_protos(handler, [@web_transport_alpn])
    else
      application_protos = get(handler, :application_protos)

      if application_protos != nil do
        if Requiem.QUIC.Config.set_application_protos(handler, application_protos) != :ok do
          raise "<Requiem.Config> Requiem.QUIC.application_protos failed"
        end
      end
    end

    # default is inifinite
    max_idle_timeout = get(handler, :max_idle_timeout)

    if max_idle_timeout != nil do
      if Requiem.QUIC.Config.set_max_idle_timeout(handler, max_idle_timeout) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.max_idle_timeout failed"
      end
    end

    # default is 65527
    max_udp_payload_size = get(handler, :max_udp_payload_size)

    if max_udp_payload_size != nil do
      if Requiem.QUIC.Config.set_max_udp_payload_size(handler, max_udp_payload_size) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.max_udp_payload_size failed"
      end
    end

    # default is 0
    initial_max_data = get(handler, :initial_max_data)

    if initial_max_data != nil do
      if Requiem.QUIC.Config.set_initial_max_data(handler, initial_max_data) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_data failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_local = get(handler, :initial_max_stream_data_bidi_local)

    if initial_max_stream_data_bidi_local != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_bidi_local(
           handler,
           initial_max_stream_data_bidi_local
         ) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_stream_data_bidi_local failed"
      end
    end

    # default is 0
    initial_max_stream_data_bidi_remote = get(handler, :initial_max_stream_data_bidi_remote)

    if initial_max_stream_data_bidi_remote != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_bidi_remote(
           handler,
           initial_max_stream_data_bidi_remote
         ) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_stream_data_bidi_remote failed"
      end
    end

    # default is 0
    initial_max_stream_data_uni = get(handler, :initial_max_stream_data_uni)

    if initial_max_stream_data_uni != nil do
      if Requiem.QUIC.Config.set_initial_max_stream_data_uni(handler, initial_max_stream_data_uni) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_stream_data_uni failed"
      end
    end

    # default is 0
    initial_max_streams_bidi = get(handler, :initial_max_streams_bidi)

    if initial_max_streams_bidi != nil do
      if Requiem.QUIC.Config.set_initial_max_streams_bidi(handler, initial_max_streams_bidi) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.initial_max_streams_bidi failed"
      end
    end

    # default is 0
    initial_max_streams_uni = get(handler, :initial_max_streams_uni)

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
    ack_delay_exponent = get(handler, :ack_delay_exponent)

    if ack_delay_exponent != nil do
      if Requiem.QUIC.Config.set_ack_delay_exponent(handler, ack_delay_exponent) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.ack_delay_exponent failed"
      end
    end

    # default is 25
    max_ack_delay = get(handler, :max_ack_delay)

    if max_ack_delay != nil do
      if Requiem.QUIC.Config.set_max_ack_delay(handler, max_ack_delay) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.max_ack_delay failed"
      end
    end

    # default is false
    disable_active_migration = get(handler, :disable_active_migration)

    if disable_active_migration != nil do
      if Requiem.QUIC.Config.set_disable_active_migration(handler, disable_active_migration) !=
           :ok do
        raise "<Requiem.Config> Requiem.QUIC.set_disable_active_migration failed"
      end
    end

    # default is "reno"
    cc_algorithm_name = get(handler, :cc_algorithm_name)

    if cc_algorithm_name != nil do
      if Requiem.QUIC.Config.set_cc_algorithm_name(handler, cc_algorithm_name) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.set_cc_algorithm_name failed"
      end
    end

    # default is false
    enable_hystart = get(handler, :enable_hystart)

    if enable_hystart != nil do
      if Requiem.QUIC.Config.enable_hystart(handler, enable_hystart) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.enable_hystart failed"
      end
    end

    # default is false
    enable_dgram = get(handler, :enable_dgram)

    if enable_dgram != nil do
      queue_size = get(handler, :dgram_queue_size)

      if Requiem.QUIC.Config.enable_dgram(handler, enable_dgram, queue_size, queue_size) != :ok do
        raise "<Requiem.Config> Requiem.QUIC.enable_dgram failed"
      end
    end
  end

  defp config_name(handler), do: Module.concat(handler, __MODULE__)
end
