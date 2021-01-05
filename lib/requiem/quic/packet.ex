defmodule Requiem.QUIC.Packet do
  alias Requiem.QUIC.NIF

  @spec parse_header(binary) ::
          {:ok, binary, binary, binary, non_neg_integer, atom, boolean}
          | {:error, :system_error | :bad_format}
  def parse_header(packet) do
    NIF.packet_parse_header(packet)
  end

  @spec create_buffer() :: {:ok, term} | {:error, :system_error}
  def create_buffer() do
    NIF.packet_build_buffer_create()
  end

  @spec build_negotiate_version(term, binary, binary) :: {:ok, binary} | {:error, :system_error}
  def build_negotiate_version(buffer, scid, dcid) do
    NIF.packet_build_negotiate_version(buffer, scid, dcid)
  end

  @spec build_retry(term, binary, binary, binary, binary, non_neg_integer) ::
          {:ok, binary} | {:error, :system_error}
  def build_retry(buffer, scid, dcid, new_scid, token, version) do
    NIF.packet_build_retry(buffer, scid, dcid, new_scid, token, version)
  end
end
