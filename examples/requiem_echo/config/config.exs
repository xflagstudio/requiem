import Config

config :requiem_echo, RequiemEcho.Handler,
  host: "0.0.0.0",
  port: 3000,
  socket_event_capacity: 1024,
  socket_polling_timeout: 100,
  cert_chain: System.get_env("CERT"),
  priv_key: System.get_env("PRIV_KEY"),
  max_idle_timeout: 60_000,
  initial_max_data: 10_000_000,
  max_udp_payload_size: 1350,
  initial_max_stream_data_bidi_local: 1_000_000,
  initial_max_stream_data_bidi_remote: 1_000_000,
  initial_max_stream_data_uni: 1_000_000,
  initial_max_streams_uni: 10,
  initial_max_streams_bidi: 10,
  disable_active_migration: true,
  enable_early_data: true,
  enable_dgram: true

