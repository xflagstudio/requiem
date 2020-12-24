defmodule Requiem.OutgoingPacket.Sender do
  defmodule Behaviour do
    @callback send(module, Requiem.Address.t(), binary) ::
                any
  end
end
