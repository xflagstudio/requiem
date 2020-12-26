defmodule Requiem.QUIC.Packet do
  alias Requiem.QUIC.NIF

  @spec parse_header(binary) ::
          {:ok, binary, binary, binary, non_neg_integer, atom, boolean}
          | {:error, :system_error | :bad_format}
  def parse_header(packet) do
    NIF.packet_parse_header(packet)
  end

  @spec build_negotiate_version(module, binary, binary) :: {:ok, binary} | {:error, :system_error}
  def build_negotiate_version(module, scid, dcid) do
    module
    |> to_string()
    |> NIF.packet_build_negotiate_version(scid, dcid)
  end

  @spec build_retry(module, binary, binary, binary, binary, non_neg_integer) ::
          {:ok, binary} | {:error, :system_error}
  def build_retry(module, scid, dcid, new_scid, token, version) do
    module
    |> to_string()
    |> NIF.packet_build_retry(scid, dcid, new_scid, token, version)
  end
end
