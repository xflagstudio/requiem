defmodule Requiem.QUIC.NIF do
  use Rustler, otp_app: :requiem, crate: "requiem_nif"

  @spec quic_init(binary, non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error}
  def quic_init(_module, _stream_buffer_num, _stream_buffer_size), do: error()

  @spec config_load_cert_chain_from_pem_file(binary, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_cert_chain_from_pem_file(_module, _file), do: error()

  @spec config_load_priv_key_from_pem_file(binary, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_priv_key_from_pem_file(_module, _file), do: error()

  @spec config_load_verify_locations_from_file(binary, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_verify_locations_from_file(_module, _file), do: error()

  @spec config_load_verify_locations_from_directory(binary, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_verify_locations_from_directory(_module, _dir), do: error()

  @spec config_verify_peer(binary, boolean) :: :ok | {:error, :system_error | :not_found}
  def config_verify_peer(_module, _verify), do: error()

  @spec config_grease(binary, boolean) :: :ok | {:error, :system_error | :not_found}
  def config_grease(_module, _grease), do: error()

  @spec config_enable_early_data(binary) :: :ok | {:error, :system_error | :not_found}
  def config_enable_early_data(_module), do: error()

  @spec config_set_application_protos(binary, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_application_protos(_module, _protos), do: error()

  @spec config_set_max_idle_timeout(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_max_idle_timeout(_module, _v), do: error()

  @spec config_set_max_udp_payload_size(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_max_udp_payload_size(_module, _v), do: error()

  @spec config_set_initial_max_data(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_data(_module, _v), do: error()

  @spec config_set_initial_max_stream_data_bidi_local(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_stream_data_bidi_local(_module, _v), do: error()

  @spec config_set_initial_max_stream_data_bidi_remote(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_stream_data_bidi_remote(_module, _v), do: error()

  @spec config_set_initial_max_stream_data_uni(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_stream_data_uni(_module, _v), do: error()

  @spec config_set_initial_max_streams_bidi(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_streams_bidi(_module, _v), do: error()

  @spec config_set_initial_max_streams_uni(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_streams_uni(_module, _v), do: error()

  @spec config_set_ack_delay_exponent(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_ack_delay_exponent(_module, _v), do: error()

  @spec config_set_max_ack_delay(binary, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_max_ack_delay(_module, _v), do: error()

  @spec config_set_disable_active_migration(binary, boolean) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_disable_active_migration(_module, _v), do: error()

  @spec config_set_cc_algorithm_name(binary, binary) :: :ok | {:error, :system_error | :not_found}
  def config_set_cc_algorithm_name(_module, _name), do: error()

  @spec config_enable_hystart(binary, boolean) :: :ok | {:error, :system_error | :not_found}
  def config_enable_hystart(_module, _v), do: error()

  @spec config_enable_dgram(binary, boolean, non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_enable_dgram(_module, _enabled, _recv_queue_len, _send_queue_len), do: error()

  @spec connection_accept(binary, binary, binary) ::
          {:ok, term} | {:error, :system_error | :not_found}
  def connection_accept(_module, _scid, _odcid), do: error()

  @spec connection_close(pid, term, boolean, non_neg_integer, binary) ::
          :ok | {:error, :system_error | :already_closed}
  def connection_close(_pid, _conn, _app, _err, _reason), do: error()

  @spec connection_is_closed(term) :: boolean
  def connection_is_closed(_conn), do: error()

  @spec connection_on_packet(pid, term, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_on_packet(_pid, _conn, _packet), do: error()

  @spec connection_on_timeout(pid, term) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_on_timeout(_pid, _conn), do: error()

  @spec connection_stream_send(pid, term, non_neg_integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_stream_send(_pid, _conn, _stream_id, _data), do: error()

  @spec connection_dgram_send(pid, term, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_dgram_send(_pid, _conn, _data), do: error()

  @spec packet_parse_header(binary) ::
          {:ok, binary, binary, binary, non_neg_integer, atom, boolean}
          | {:error, :system_error | :bad_format}
  def packet_parse_header(_packet), do: error()

  @spec packet_build_buffer_create() ::
          {:ok, term} | {:error, :system_error}
  def packet_build_buffer_create(), do: error()

  @spec packet_build_negotiate_version(term, binary, binary) ::
          {:ok, binary} | {:error, :system_error}
  def packet_build_negotiate_version(_buffer, _scid, _dcid), do: error()

  @spec packet_build_retry(term, binary, binary, binary, binary, non_neg_integer) ::
          {:ok, binary} | {:error, :system_error}
  def packet_build_retry(_buffer, _scid, _dcid, _new_scid, _token, _version), do: error()

  @spec socket_open(binary, binary, pid, [pid], non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error | :cant_bind}
  def socket_open(_module, _address, _pid, _target_pids, _event_capacity, _poll_interval),
    do: error()

  @spec socket_send(binary, term, binary) ::
          :ok | {:error, :system_error | :not_found}
  def socket_send(_module, _addr, _packet), do: error()

  @spec socket_close(binary) ::
          :ok | {:error, :system_error | :not_found}
  def socket_close(_module), do: error()

  @spec socket_address_parts(term) ::
          {:ok, binary, non_neg_integer}
  def socket_address_parts(_address), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
