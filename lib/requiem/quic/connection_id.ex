defmodule Requiem.QUIC.ConnectionID do
  @spec generate_from_odcid(binary, binary) :: {:ok, binary} | :error
  def generate_from_odcid(key, odcid) do
    case :crypto.hmac(:sha256, key, odcid) do
      <<new_id::binary-size(20), _rest::binary>> -> {:ok, new_id}
      _ -> :error
    end
  end
end
