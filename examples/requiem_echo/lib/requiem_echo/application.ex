defmodule RequiemEcho.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RequiemEcho.Handler
    ]

    opts = [strategy: :one_for_one, name: RequiemEcho.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
