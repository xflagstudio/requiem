import Config

config :requiem_echo, RequiemEcho.Handler,
  port: 3000,
  cert_chain: System.get_env("CERT"),
  priv_key: System.get_env("PRIV_KEY"),
  max_idle_timeout: 50000,
  initial_max_data: 10_000_000,
  max_udp_payload_size: 1350,
  initial_max_stream_data_bidi_local: 1_000_000,
  initial_max_stream_data_bidi_remote: 1_000_000,
  initial_max_stream_data_uni: 1_000_000,
  initial_max_streams_uni: 10,
  initial_max_streams_bidi: 10,
  disable_active_migration: true,
  enable_early_data: true,
  rust_transport: true,
  rust_transport_host: "0.0.0.0",
  enable_dgram: true

config :requiem, :trace, true
