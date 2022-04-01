defmodule Requiem.ConnectRequest do
  @type t :: %__MODULE__{
          session_id: integer,
          origin: binary,
          authority: binary,
          path: binary
        }

  defstruct session_id: 0,
            origin: "",
            authority: "",
            path: ""

  @spec new(integer, binary, binary, binary) :: t
  def new(session_id, authority, path, origin) do
    %__MODULE__{
      session_id: session_id,
      authority: authority,
      path: path,
      origin: origin
    }
  end
end
