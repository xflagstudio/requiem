defmodule Requiem.Address do
  use Bitwise

  alias Requiem.QUIC

  @type t :: %__MODULE__{
          host: :inet.ip_address(),
          port: :inet.port_number(),
          raw: nil | term
        }

  defstruct host: nil, port: nil, raw: nil

  @spec from_rust_peer(term) :: t
  def from_rust_peer(peer) do
    {:ok, host, port} = QUIC.Socket.address_parts(peer)

    if byte_size(host) == 4 do
      <<n1, n2, n3, n4>> = host
      new({n1, n2, n3, n4}, port, peer)
    else
      <<
        n1::unsigned-integer-size(16),
        n2::unsigned-integer-size(16),
        n3::unsigned-integer-size(16),
        n4::unsigned-integer-size(16),
        n5::unsigned-integer-size(16),
        n6::unsigned-integer-size(16),
        n7::unsigned-integer-size(16),
        n8::unsigned-integer-size(16)
      >> = host

      new({n1, n2, n3, n4, n5, n6, n7, n8}, port, peer)
    end
  end

  @spec new(:inet.ip_address(), :inet.port_number(), term | nil) :: t
  def new(host, port, raw \\ nil) do
    %__MODULE__{
      host: host,
      port: port,
      raw: raw
    }
  end

  @spec to_binary(t) :: binary
  def to_binary(%__MODULE__{host: {n1, n2, n3, n4}, port: port}) do
    <<0x00, n1, n2, n3, n4, port::unsigned-integer-size(16)>>
  end

  def to_binary(%__MODULE__{host: {n1, n2, n3, n4, n5, n6, n7, n8}, port: port}) do
    <<0x01, n1::unsigned-integer-size(16), n2::unsigned-integer-size(16),
      n3::unsigned-integer-size(16), n4::unsigned-integer-size(16), n5::unsigned-integer-size(16),
      n6::unsigned-integer-size(16), n7::unsigned-integer-size(16), n8::unsigned-integer-size(16),
      port::unsigned-integer-size(16)>>
  end

  @spec from_binary(binary) :: {:ok, t} | :error
  def from_binary(data) do
    case data do
      <<0x00, n1, n2, n3, n4, port::unsigned-integer-size(16)>> ->
        {:ok, new({n1, n2, n3, n4}, port)}

      <<0x01, n1::unsigned-integer-size(16), n2::unsigned-integer-size(16),
        n3::unsigned-integer-size(16), n4::unsigned-integer-size(16),
        n5::unsigned-integer-size(16), n6::unsigned-integer-size(16),
        n7::unsigned-integer-size(16), n8::unsigned-integer-size(16),
        port::unsigned-integer-size(16)>> ->
        {:ok, new({n1, n2, n3, n4, n5, n6, n7, n8}, port)}

      _ ->
        :error
    end
  end

  @spec same?(t, t) :: boolean
  def same?(addr1, addr2) do
    addr1.host == addr2.host && addr1.port == addr2.port
  end

  @spec to_udp_header(t) :: list
  def to_udp_header(%__MODULE__{host: {_, _, _, _} = host, port: port}) do
    [1, int16(port), ip4_to_bytes(host)]
  end

  def to_udp_header(%__MODULE__{host: {_, _, _, _, _, _, _, _} = host, port: port}) do
    [2, int16(port), ip6_to_bytes(host)]
  end

  defp int16(port) do
    [
      band(bsr(port, 8), 0xFF),
      band(port, 0xFF)
    ]
  end

  defp ip4_to_bytes({n1, n2, n3, n4}) do
    [
      band(n1, 0xFF),
      band(n2, 0xFF),
      band(n3, 0xFF),
      band(n4, 0xFF)
    ]
  end

  defp ip6_to_bytes({n1, n2, n3, n4, n5, n6, n7, n8}) do
    [
      band(n1, 0xFF),
      band(bsr(n2, 8), 0xFF),
      band(n2, 0xFF),
      band(bsr(n3, 8), 0xFF),
      band(n3, 0xFF),
      band(bsr(n4, 8), 0xFF),
      band(n4, 0xFF),
      band(bsr(n5, 8), 0xFF),
      band(n5, 0xFF),
      band(bsr(n6, 8), 0xFF),
      band(n6, 0xFF),
      band(bsr(n7, 8), 0xFF),
      band(n7, 0xFF),
      band(bsr(n8, 8), 0xFF),
      band(n8, 0xFF)
    ]
  end
end

defimpl String.Chars, for: Requiem.Address do
  def to_string(%Requiem.Address{host: {n1, n2, n3, n4}, port: port}) do
    "#{n1}.#{n2}.#{n3}.#{n4}:#{port}"
  end

  def to_string(%Requiem.Address{host: {n1, n2, n3, n4, n5, n6, n7, n8}, port: port}) do
    "#{n1}.#{n2}.#{n3}.#{n4}.#{n5}.#{n6}.#{n7}.#{n8}:#{port}"
  end
end
