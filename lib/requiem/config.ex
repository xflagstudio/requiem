defmodule Requiem.Config do
  @moduledoc """
  Config helper module
  """

  @type config_key ::
          :web_transport
          | :host
          | :port
          | :sender_buffering_interval
          | :dispatcher_pool_size
          | :stream_buffer_pool_size
          | :stream_buffer_size
          | :rust_transport
          | :socket_event_capacity
          | :socket_polling_timeout
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
    host: "0.0.0.0",
    port: 443,
    sender_buffering_interval: 0,
    dispatcher_pool_size: 10,
    stream_buffer_pool_size: 10,
    stream_buffer_size: 1024 * 1024,
    token_secret: :crypto.strong_rand_bytes(16),
    connection_id_secret: :crypto.strong_rand_bytes(32),
    dgram_queue_size: 1000,
    max_idle_timeout: 60_000,
    rust_transport: true,
    socket_event_capacity: 1024,
    socket_polling_timeout: 10
  ]

  @key_table %{
    web_transport: true,
    port: true,
    host: true,
    sender_buffering_interval: true,
    dispatcher_pool_size: true,
    stream_buffer_pool_size: true,
    stream_buffer_size: true,
    rust_transport: true,
    socket_event_capacity: true,
    socket_polling_timeout: true,
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

  @spec init(module, atom) :: no_return
  def init(handler, otp_app) do
    config1 = Application.get_env(otp_app, handler, [])
    config2 = Keyword.merge(@default_values, config1)
    check_key_existence(config2)
    store(handler, config2)
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

  defp config_name(handler), do: Module.concat(handler, __MODULE__)
end
