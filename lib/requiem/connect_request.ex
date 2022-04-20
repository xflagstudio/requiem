defmodule Requiem.ConnectRequest do
  @type t :: %__MODULE__{
          origin: binary,
          authority: binary,
          path: binary
        }

  defstruct origin: "",
            authority: "",
            path: ""

  @spec new(binary, binary, binary) :: t
  def new(authority, path, origin) do
    %__MODULE__{
      authority: authority,
      path: path,
      origin: origin
    }
  end
end
