defmodule Requiem.IncomingPacket.Dispatcher do
  defmodule Behaviour do
    @callback dispatch(
                module,
                Requiem.Address.t(),
                binary
              ) ::
                any
  end
end
