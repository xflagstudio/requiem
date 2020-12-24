defmodule Requiem.QUIC do
  alias Requiem.QUIC.NIF

  @spec init(module) :: :ok | {:error, :system_error}
  def init(module) do
    module
    |> to_string()
    |> NIF.quic_init()
  end
end
