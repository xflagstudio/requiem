defmodule Requiem.ExceptionGuard do
  require Logger

  def guard(error_resp, func) do
    try do
      func.()
    rescue
      err ->
        stacktrace = __STACKTRACE__ |> Exception.format_stacktrace()

        Logger.error(
          "<Requiem.Connection:#{self()}> rescued error - #{inspect(err)}, stacktrace - #{
            stacktrace
          }"
        )

        error_resp.()
    catch
      error_type, value when error_type in [:throw, :exit] ->
        stacktrace = __STACKTRACE__ |> Exception.format_stacktrace()

        Logger.error(
          "<Requiem.Connection:#{self()}> caught error - #{inspect(value)}, stacktrace - #{
            stacktrace
          }"
        )

        error_resp.()
    end
  end
end
