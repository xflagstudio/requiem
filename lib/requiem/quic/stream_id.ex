defmodule Requiem.QUIC.StreamId do
  @type orientation :: :bidi | :uni
  @type initiator :: :server | :client

  @spec is_bidi(non_neg_integer) :: boolean
  def is_bidi(stream_id) do
    case classify(stream_id) do
      {:ok, _, :bidi} -> true
      _ -> false
    end
  end

  @spec is_uni(non_neg_integer) :: boolean
  def is_uni(stream_id) do
    case classify(stream_id) do
      {:ok, _, :uni} -> true
      _ -> false
    end
  end

  @spec is_client_initiated(non_neg_integer) :: boolean
  def is_client_initiated(stream_id) do
    case classify(stream_id) do
      {:ok, :client, _} -> true
      _ -> false
    end
  end

  @spec is_server_initiated(non_neg_integer) :: boolean
  def is_server_initiated(stream_id) do
    case classify(stream_id) do
      {:ok, :server, _} -> true
      _ -> false
    end
  end

  @spec classify(non_neg_integer) :: {:ok, initiator(), orientation()} | :error
  def classify(stream_id) do
    case <<stream_id::unsigned-integer-size(64)>> do
      <<_num::62, last_two_bits::2>> ->
        classify_by_last_two_bits(last_two_bits)

      _ ->
        :error
    end
  end

  defp classify_by_last_two_bits(bits) do
    case bits do
      0x00 -> {:ok, :client, :bidi}
      0x01 -> {:ok, :server, :bidi}
      0x02 -> {:ok, :client, :uni}
      0x03 -> {:ok, :server, :uni}
      _ -> :error
    end
  end
end
