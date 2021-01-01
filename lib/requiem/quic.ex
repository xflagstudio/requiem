defmodule Requiem.QUIC do
  alias Requiem.QUIC.NIF

  @spec init(module, non_neg_integer, non_neg_integer, non_neg_integer) ::
          :ok | {:error, :system_error}
  def init(module, retry_buffer_num \\ 5, stream_buffer_num \\ 10, stream_buffer_size \\ 8092) do
    module
    |> to_string()
    |> NIF.quic_init(
      retry_buffer_num,
      stream_buffer_num,
      stream_buffer_size
    )
  end
end
