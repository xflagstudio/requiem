defmodule Requiem.QUIC.RetryToken do
  alias Requiem.Address

  defmodule Params do
    @spec format(binary, binary, Address.t()) :: binary
    def format(odcid, retry_scid, addr) do
      odcid_len = byte_size(odcid)
      retry_scid_len = byte_size(retry_scid)

      encoded_addr = Address.to_binary(addr)

      <<
        odcid_len::unsigned-integer-size(16),
        retry_scid_len::unsigned-integer-size(16),
        odcid::binary,
        retry_scid::binary,
        encoded_addr::binary
      >>
    end

    @spec parse(binary) :: {:ok, binary, binary, Address.t()} | :error
    def parse(data) do
      case data do
        <<
          odcid_len::unsigned-integer-size(16),
          retry_scid_len::unsigned-integer-size(16),
          rest1::binary
        >> ->
          case rest1 do
            <<
              odcid::binary-size(odcid_len),
              retry_scid::binary-size(retry_scid_len),
              rest2::binary
            >> ->
              case Address.from_binary(rest2) do
                {:ok, addr} ->
                  {:ok, odcid, retry_scid, addr}

                :error ->
                  :error
              end

            _ ->
              :error
          end

        _ ->
          :error
      end
    end
  end

  defmodule Protector do
    @aad "AES128GCM"
    @info "Requiem QUIC Token"

    @spec encrypt(binary, binary, binary) :: {:ok, binary, binary} | :error
    def encrypt(secret, nonce, token) do
      case derive_key_and_iv(secret, nonce) do
        {:ok, key, iv} ->
          case :crypto.block_encrypt(:aes_gcm, key, iv, {@aad, token, 16}) do
            {ciphertext, tag} -> {:ok, ciphertext, tag}
            _ -> :error
          end

        :error ->
          :error
      end
    end

    @spec decrypt(binary, binary, binary, binary) :: {:ok, binary} | :error
    def decrypt(secret, nonce, tag, token) do
      case derive_key_and_iv(secret, nonce) do
        {:ok, key, iv} ->
          case :crypto.block_decrypt(:aes_gcm, key, iv, {@aad, token, tag}) do
            result when is_binary(result) -> {:ok, result}
            _ -> :error
          end

        :error ->
          :error
      end
    end

    @spec derive_key_and_iv(binary, binary) :: {:ok, binary, binary} | :error
    def derive_key_and_iv(secret, nonce) do
      case HKDF.derive(:sha256, secret, 44, nonce, @info) do
        <<key::binary-size(32), iv::binary-size(12)>> -> {:ok, key, iv}
        _ -> :error
      end
    end
  end

  @spec create(Address.t(), binary, binary, binary) :: {:ok, binary} | :error
  def create(addr, odcid, retry_scid, secret) do
    plain = Params.format(odcid, retry_scid, addr)
    nonce = :crypto.strong_rand_bytes(16)

    case Protector.encrypt(secret, nonce, plain) do
      {:ok, ciphertext, tag} -> {:ok, <<nonce::binary, tag::binary, ciphertext::binary>>}
      :error -> :error
    end
  end

  @spec validate(Address.t(), binary, binary) :: {:ok, binary, binary} | :error
  def validate(addr, secret, token) do
    case token do
      <<nonce::binary-size(16), tag::binary-size(16), rest::binary>> ->
        case Protector.decrypt(secret, nonce, tag, rest) do
          {:ok, plain} ->
            case Params.parse(plain) do
              {:ok, odcid, retry_scid, addr2} ->
                if Address.same?(addr, addr2) do
                  {:ok, odcid, retry_scid}
                else
                  :error
                end

              :error ->
                :error
            end

          :error ->
            :error
        end

      _ ->
        :error
    end
  end
end
