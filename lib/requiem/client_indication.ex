defmodule Requiem.ClientIndication do
  @type t :: %__MODULE__{
          origin: binary,
          path: binary
        }

  defstruct origin: "",
            path: ""

  @spec to_binary(t) :: binary
  def to_binary(indication) do
    %{0x0000 => indication.origin, 0x0001 => indication.path}
    |> build()
  end

  @spec from_binary(binary) :: {:ok, t} | :error
  def from_binary(data) do
    case parse(data) do
      {:ok, map} ->
        origin =
          if Map.has_key?(map, 0x0000) do
            Map.get(map, 0x0000, "")
          else
            ""
          end

        path =
          if Map.has_key?(map, 0x0001) do
            Map.get(map, 0x0001, "")
          else
            ""
          end

        indication = %__MODULE__{
          origin: origin,
          path: path
        }

        {:ok, indication}

      :error ->
        :error
    end
  end

  @spec build(map) :: binary
  defp build(map) do
    Enum.map(map, fn {k, v} ->
      l = byte_size(v)
      <<k::unsigned-integer-size(16), l::unsigned-integer-size(16), v::binary>>
    end)
    |> Enum.reduce(<<>>, fn x, acc ->
      <<acc::binary, x::binary>>
    end)
  end

  @spec parse(binary) :: {:ok, map} | :error
  defp parse(data) do
    parse(data, %{})
  end

  defp parse(data, result) do
    case data do
      <<>> ->
        {:ok, result}

      <<key::unsigned-integer-size(16), len::unsigned-integer-size(16), rest::binary>> ->
        case parse_value(rest, len) do
          {:ok, value, rest2} ->
            result2 = Map.put(result, key, value)
            parse(rest2, result2)

          _ ->
            :error
        end

      _ ->
        :error
    end
  end

  defp parse_value(data, len) do
    case data do
      <<value::binary-size(len), rest::binary>> ->
        {:ok, value, rest}

      _ ->
        :error
    end
  end
end
