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

  @spec load_cert_chain_from_pem_file(module, binary) ::
          :ok | {:error, :system_error | :not_found}
  def load_cert_chain_from_pem_file(module, file) do
    module
    |> to_string()
    |> NIF.config_load_cert_chain_from_pem_file(file)
  end

  @spec load_priv_key_from_pem_file(module, binary) :: :ok | {:error, :system_error | :not_found}
  def load_priv_key_from_pem_file(module, file) do
    module
    |> to_string()
    |> NIF.config_load_priv_key_from_pem_file(file)
  end

  @spec load_verify_locations_from_file(module, binary) ::
          :ok | {:error, :system_error | :not_found}
  def load_verify_locations_from_file(module, file) do
    module
    |> to_string()
    |> NIF.config_load_verify_locations_from_file(file)
  end

  @spec load_verify_locations_from_directory(module, binary) ::
          :ok | {:error, :system_error | :not_found}
  def load_verify_locations_from_directory(module, dir) do
    module
    |> to_string()
    |> NIF.config_load_verify_locations_from_directory(dir)
  end

  @spec verify_peer(module, boolean) :: :ok | {:error, :system_error | :not_found}
  def verify_peer(module, verify) do
    module
    |> to_string()
    |> NIF.config_verify_peer(verify)
  end

  @spec grease(module, boolean) :: :ok | {:error, :system_error | :not_found}
  def grease(module, grease) do
    module
    |> to_string()
    |> NIF.config_grease(grease)
  end

  @spec enable_early_data(module) :: :ok | {:error, :system_error | :not_found}
  def enable_early_data(module) do
    module
    |> to_string()
    |> NIF.config_enable_early_data()
  end

  @spec set_application_protos(module, list) :: :ok | {:error, :system_error | :not_found}
  def set_application_protos(module, protos) do
    module
    |> to_string()
    |> NIF.config_set_application_protos(ALPN.encode_list(protos))
  end

  @spec set_max_idle_timeout(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_max_idle_timeout(module, v) do
    module
    |> to_string()
    |> NIF.config_set_max_idle_timeout(v)
  end

  @spec set_max_udp_payload_size(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_max_udp_payload_size(module, v) do
    module
    |> to_string()
    |> NIF.config_set_max_udp_payload_size(v)
  end

  @spec set_initial_max_data(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_data(module, v) do
    module
    |> to_string()
    |> NIF.config_set_initial_max_data(v)
  end

  @spec set_initial_max_stream_data_bidi_local(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_stream_data_bidi_local(module, v) do
    module
    |> to_string()
    |> NIF.config_set_initial_max_stream_data_bidi_local(v)
  end

  @spec set_initial_max_stream_data_bidi_remote(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_stream_data_bidi_remote(module, v) do
    module
    |> to_string()
    |> NIF.config_set_initial_max_stream_data_bidi_remote(v)
  end

  @spec set_initial_max_stream_data_uni(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_stream_data_uni(module, v) do
    module
    |> to_string()
    |> NIF.config_set_initial_max_stream_data_uni(v)
  end

  @spec set_initial_max_streams_bidi(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_streams_bidi(module, v) do
    module
    |> to_string()
    |> NIF.config_set_initial_max_streams_bidi(v)
  end

  @spec set_initial_max_streams_uni(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_initial_max_streams_uni(module, v) do
    module
    |> to_string()
    |> NIF.config_set_initial_max_streams_uni(v)
  end

  @spec set_ack_delay_exponent(module, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def set_ack_delay_exponent(module, v) do
    module
    |> to_string()
    |> NIF.config_set_ack_delay_exponent(v)
  end

  @spec set_max_ack_delay(module, non_neg_integer) :: :ok | {:error, :system_error | :not_found}
  def set_max_ack_delay(module, v) do
    module
    |> to_string()
    |> NIF.config_set_max_ack_delay(v)
  end

  @spec set_disable_active_migration(module, boolean) ::
          :ok | {:error, :system_error | :not_found}
  def set_disable_active_migration(module, v) do
    module
    |> to_string()
    |> NIF.config_set_disable_active_migration(v)
  end

  @spec set_cc_algorithm_name(module, binary) :: :ok | {:error, :system_error | :not_found}
  def set_cc_algorithm_name(module, name) do
    module
    |> to_string()
    |> NIF.config_set_cc_algorithm_name(name)
  end

  @spec enable_hystart(module, boolean) :: :ok | {:error, :system_error | :not_found}
  def enable_hystart(module, v) do
    module
    |> to_string()
    |> NIF.config_enable_hystart(v)
  end

  @spec enable_dgram(module, boolean, non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error | :not_found}
  def enable_dgram(module, enabled, recv_queue_len, send_queue_len) do
    module
    |> to_string()
    |> NIF.config_enable_dgram(enabled, recv_queue_len, send_queue_len)
  end
end
