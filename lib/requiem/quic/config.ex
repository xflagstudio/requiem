defmodule Requiem.QUIC.Config do
  alias Requiem.QUIC.NIF

  defmodule ALPN do
    @spec encode_list(list) :: binary
    def encode_list(list) do
      list
      |> Enum.map(&encode/1)
      |> Enum.reduce(<<>>, fn x, acc -> <<acc::binary, x::binary>> end)
    end

    @spec encode(String.t()) :: binary
    def encode(proto) do
      <<byte_size(proto)::8, proto::binary>>
    end
  end

  @spec new() ::
          {:ok, integer} | {:error, :system_error | :not_found}
  def new() do
    NIF.config_new()
  end

  @spec destroy(integer) ::
          :ok | {:error, :system_error | :not_found}
  def destroy(ptr) do
    NIF.config_destroy(ptr)
  end

  @spec load_cert_chain_from_pem_file(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def load_cert_chain_from_pem_file(ptr, file) do
    NIF.config_load_cert_chain_from_pem_file(ptr, file)
  end

  @spec load_priv_key_from_pem_file(integer, binary) :: :ok | {:error, :system_error | :not_found}
  def load_priv_key_from_pem_file(ptr, file) do
    NIF.config_load_priv_key_from_pem_file(ptr, file)
  end

  @spec load_verify_locations_from_file(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def load_verify_locations_from_file(ptr, file) do
    NIF.config_load_verify_locations_from_file(ptr, file)
  end

  @spec load_verify_locations_from_directory(integer, binary) ::
          :ok | {:error, :system_error | :not_found}
  def load_verify_locations_from_directory(ptr, dir) do
    NIF.config_load_verify_locations_from_directory(ptr, dir)
  end

  @spec verify_peer(integer, boolean) :: :ok | {:error, :system_error | :not_found}
  def verify_peer(ptr, verify) do
    NIF.config_verify_peer(ptr, verify)
  end

  @spec grease(integer, boolean) :: :ok | {:error, :system_error | :not_found}
  def grease(ptr, grease) do
    NIF.config_grease(ptr, grease)
  end

  @spec enable_early_data(integer) :: :ok | {:error, :system_error | :not_found}
  def enable_early_data(ptr) do
    NIF.config_enable_early_data(ptr)
  end

  @spec set_application_protos(integer, list) :: :ok | {:error, :system_error | :not_found}
  def set_application_protos(ptr, protos) do
    NIF.config_set_application_protos(ptr, ALPN.encode_list(protos))
  end

  @spec set_max_idle_timeout(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_max_idle_timeout(ptr, v) do
    NIF.config_set_max_idle_timeout(ptr, v)
  end

  @spec set_max_udp_payload_size(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_max_udp_payload_size(ptr, v) do
    NIF.config_set_max_udp_payload_size(ptr, v)
  end

  @spec set_initial_max_data(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_data(ptr, v) do
    NIF.config_set_initial_max_data(ptr, v)
  end

  @spec set_initial_max_stream_data_bidi_local(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_stream_data_bidi_local(ptr, v) do
    NIF.config_set_initial_max_stream_data_bidi_local(ptr, v)
  end

  @spec set_initial_max_stream_data_bidi_remote(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_stream_data_bidi_remote(ptr, v) do
    NIF.config_set_initial_max_stream_data_bidi_remote(ptr, v)
  end

  @spec set_initial_max_stream_data_uni(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_stream_data_uni(ptr, v) do
    NIF.config_set_initial_max_stream_data_uni(ptr, v)
  end

  @spec set_initial_max_streams_bidi(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_streams_bidi(ptr, v) do
    NIF.config_set_initial_max_streams_bidi(ptr, v)
  end

  @spec set_initial_max_streams_uni(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_streams_uni(ptr, v) do
    NIF.config_set_initial_max_streams_uni(ptr, v)
  end

  @spec set_ack_delay_exponent(integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_ack_delay_exponent(ptr, v) do
    NIF.config_set_ack_delay_exponent(ptr, v)
  end

  @spec set_max_ack_delay(integer, non_neg_integer) :: :ok | {:error, :system_error | :not_found}
  def set_max_ack_delay(ptr, v) do
    NIF.config_set_max_ack_delay(ptr, v)
  end

  @spec set_disable_active_migration(integer, boolean) ::
          :ok | {:error, :system_error | :not_found}
  def set_disable_active_migration(ptr, v) do
    NIF.config_set_disable_active_migration(ptr, v)
  end

  @spec set_cc_algorithm_name(integer, binary) :: :ok | {:error, :system_error | :not_found}
  def set_cc_algorithm_name(ptr, name) do
    NIF.config_set_cc_algorithm_name(ptr, name)
  end

  @spec enable_hystart(integer, boolean) :: :ok | {:error, :system_error | :not_found}
  def enable_hystart(ptr, v) do
    NIF.config_enable_hystart(ptr, v)
  end

  @spec enable_dgram(integer, boolean, non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def enable_dgram(ptr, enabled, recv_queue_len, send_queue_len) do
    NIF.config_enable_dgram(ptr, enabled, recv_queue_len, send_queue_len)
  end
end
