defmodule Requiem.DispatcherRegistry do
  @spec gather(module, non_neg_integer) :: [pid]
  def gather(handler, number_of_workers) do
    0..(number_of_workers - 1)
    |> Enum.flat_map(fn index ->
      case lookup(handler, index) do
        {:ok, pid} -> [pid]
        _ -> []
      end
    end)
  end

  @spec register(module, non_neg_integer) ::
          {:ok, pid()}
          | {:error, {:already_registered, pid()}}
  def register(handler, worker_index) do
    handler |> name() |> Registry.register(worker_index, nil)
  end

  @spec unregister(module, non_neg_integer) :: :ok
  def unregister(handler, worker_index) do
    handler |> name() |> Registry.unregister(worker_index)
  end

  @spec lookup(module, non_neg_integer) ::
          {:ok, pid()}
          | {:error, :not_found}
  def lookup(handler, worker_index) do
    case handler |> name() |> Registry.lookup(worker_index) do
      [{pid, _}] -> {:ok, pid}
      _ -> {:error, :not_found}
    end
  end

  def name(handler),
    do: Module.concat(handler, __MODULE__)
end
