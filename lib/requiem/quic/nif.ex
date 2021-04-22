defmodule Requiem.QUIC.NIF do
  use Rustler, otp_app: :requiem, crate: "requiem_nif"

  @spec config_new() ::
          {:ok, integer} | {:error, :system_error | :not_found}
  def config_new(), do: error()

  @spec config_destroy(integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_destroy(_ptr), do: error()

  @spec config_load_cert_chain_from_pem_file(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_cert_chain_from_pem_file(_ptr, _file), do: error()

  @spec config_load_priv_key_from_pem_file(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_priv_key_from_pem_file(_ptr, _file), do: error()

  @spec config_load_verify_locations_from_file(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_verify_locations_from_file(_ptr, _file), do: error()

  @spec config_load_verify_locations_from_directory(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_load_verify_locations_from_directory(_ptr, _dir), do: error()

  @spec config_verify_peer(integer, boolean) :: :ok | {:error, :system_error | :not_found}
  def config_verify_peer(_ptr, _verify), do: error()

  @spec config_grease(integer, boolean) :: :ok | {:error, :system_error | :not_found}
  def config_grease(_ptr, _grease), do: error()

  @spec config_enable_early_data(integer) :: :ok | {:error, :system_error | :not_found}
  def config_enable_early_data(_ptr), do: error()

  @spec config_set_application_protos(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_application_protos(_ptr, _protos), do: error()

  @spec config_set_max_idle_timeout(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_max_idle_timeout(_ptr, _v), do: error()

  @spec config_set_max_udp_payload_size(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_max_udp_payload_size(_ptr, _v), do: error()

  @spec config_set_initial_max_data(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_data(_ptr, _v), do: error()

  @spec config_set_initial_max_stream_data_bidi_local(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_stream_data_bidi_local(_ptr, _v), do: error()

  @spec config_set_initial_max_stream_data_bidi_remote(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_stream_data_bidi_remote(_ptr, _v), do: error()

  @spec config_set_initial_max_stream_data_uni(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_stream_data_uni(_ptr, _v), do: error()

  @spec config_set_initial_max_streams_bidi(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_streams_bidi(_ptr, _v), do: error()

  @spec config_set_initial_max_streams_uni(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_initial_max_streams_uni(_ptr, _v), do: error()

  @spec config_set_ack_delay_exponent(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_ack_delay_exponent(_ptr, _v), do: error()

  @spec config_set_max_ack_delay(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_max_ack_delay(_ptr, _v), do: error()

  @spec config_set_disable_active_migration(integer, boolean) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_disable_active_migration(_ptr, _v), do: error()

  @spec config_set_cc_algorithm_name(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def config_set_cc_algorithm_name(_ptr, _name), do: error()

  @spec config_enable_hystart(integer, boolean) :: :ok | {:error, :system_error | :not_found}
  def config_enable_hystart(_ptr, _v), do: error()

  @spec config_enable_dgram(integer, boolean, non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def config_enable_dgram(_ptr, _enabled, _recv_queue_len, _send_queue_len), do: error()

  @spec connection_accept(integer, binary, binary, term, pid, non_neg_integer) ::
          {:ok, integer} | {:error, :system_error | :not_found}
  def connection_accept(_config_ptr, _scid, _odcid, _peer, _sender_pid, _stream_buf_size),
    do: error()

  @spec connection_destroy(integer) ::
          :ok | {:error, :system_error | :not_found}
  def connection_destroy(_conn_ptr), do: error()

  @spec connection_close(integer, boolean, non_neg_integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_close(_conn, _app, _err, _reason), do: error()

  @spec connection_is_closed(integer) :: boolean
  def connection_is_closed(_conn), do: error()

  @spec connection_on_packet(pid, integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_on_packet(_pid, _conn, _packet), do: error()

  @spec connection_on_timeout(integer) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_on_timeout(_conn), do: error()

  @spec connection_stream_send(integer, non_neg_integer, binary, boolean) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_stream_send(_conn, _stream_id, _data, _fin), do: error()

  @spec connection_dgram_send(integer, binary) ::
          {:ok, non_neg_integer} | {:error, :system_error | :already_closed}
  def connection_dgram_send(_conn, _data), do: error()

  @spec packet_builder_new() ::
          {:ok, integer} | {:error, :system_error}
  def packet_builder_new(), do: error()

  @spec packet_builder_destroy(integer) ::
          :ok | {:error, :system_error}
  def packet_builder_destroy(_builder), do: error()

  @spec packet_builder_build_negotiate_version(integer, binary, binary) ::
          {:ok, binary} | {:error, :system_error}
  def packet_builder_build_negotiate_version(_builder, _scid, _dcid), do: error()

  @spec packet_builder_build_retry(integer, binary, binary, binary, binary, non_neg_integer) ::
          {:ok, binary} | {:error, :system_error}
  def packet_builder_build_retry(_builder, _scid, _dcid, _new_scid, _token, _version), do: error()

  @spec cpu_num() ::
          integer | {:error, :system_error | :not_found}
  def cpu_num(), do: error()

  @spec socket_sender_get(integer, non_neg_integer) ::
          {:ok, integer} | {:error, :system_error | :not_found}
  def socket_sender_get(_socket_ptr, _idx), do: error()

  @spec socket_sender_send(integer, term, binary) ::
          :ok | {:error, :system_error | :not_found}
  def socket_sender_send(_socket_ptr, _addr, _packet), do: error()

  @spec socket_sender_destroy(integer) ::
          :ok | {:error, :system_error | :not_found}
  def socket_sender_destroy(_socket_ptr), do: error()

  @spec socket_new(integer) ::
          {:ok, integer} | {:error, :system_error | :socket_error}
  def socket_new(_num_node),
    do: error()

  @spec socket_start(integer, binary, pid, [pid]) ::
          :ok | {:error, :system_error | :not_found}
  def socket_start(_ptr, _address, _pid, _target_pids), do: error()

  @spec socket_destroy(integer) ::
          :ok | {:error, :system_error | :not_found}
  def socket_destroy(_ptr), do: error()

  @spec socket_address_parts(term) ::
          {:ok, binary, non_neg_integer}
  def socket_address_parts(_address), do: error()

  @spec socket_address_from_string(binary) ::
          {:ok, term} | {:error, :bad_format}
  def socket_address_from_string(_address), do: error()

  defp error(), do: :erlang.nif_error(:nif_not_loaded)
end
