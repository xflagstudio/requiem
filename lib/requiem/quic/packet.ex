defmodule Requiem.QUIC.PacketBuilder do
  alias Requiem.QUIC.NIF

  @spec new() :: {:ok, integer} | {:error, :system_error}
  def new() do
    NIF.packet_builder_new()
  end

  @spec destroy(integer) :: :ok | {:error, :system_error}
  def destroy(builder) do
    NIF.packet_builder_destroy(builder)
  end

  @spec build_negotiate_version(integer, binary, binary) :: {:ok, binary} | {:error, :system_error}
  def build_negotiate_version(builder, scid, dcid) do
    NIF.packet_builder_build_negotiate_version(builder, scid, dcid)
  end

  @spec build_retry(integer, binary, binary, binary, binary, non_neg_integer) ::
          {:ok, binary} | {:error, :system_error}
  def build_retry(builder, scid, dcid, new_scid, token, version) do
    NIF.packet_builder_build_retry(builder, scid, dcid, new_scid, token, version)
  end
end
