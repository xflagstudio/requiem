defmodule Requiem.ConnectionRegistry do
  @moduledoc """
  QUIC connection process registry
  """

  @doc """
  Register a QUIC connection process with connection-id.
  """
  @spec register(module, String.t()) ::
          {:ok, pid()}
          | {:error, {:already_registered, pid()}}
  def register(handler, conn_id) do
    handler |> name() |> Registry.register(conn_id, nil)
  end

  @doc """
  Unregister a QUIC connection process.
  """
  @spec unregister(module, String.t()) :: :ok
  def unregister(handler, conn_id) do
    handler |> name() |> Registry.unregister(conn_id)
  end

  @doc """
  Find a QUIC connection process by connection-id.
  """
  @spec lookup(module, String.t()) ::
          {:ok, pid()}
          | {:error, :not_found}
  def lookup(handler, conn_id) do
    case handler |> name() |> Registry.lookup(conn_id) do
      [{pid, _}] -> {:ok, pid}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Returns the registry name.
  """
  def name(handler),
    do: Module.concat(handler, __MODULE__)
end
