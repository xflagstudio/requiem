defmodule Requiem.Tracer do
  @traceable Application.compile_env(:requiem, :trace, false)
  defmacro trace(caller, msg) do
    if @traceable do
      quote do
        require Logger
        Logger.debug("<#{unquote(caller)}> #{unquote(msg)}")
      end
    else
      quote do
        # This is useless, just for suppressing unused-variable-warnings.
        if false do
          require Logger
          Logger.debug("<#{unquote(caller)}> #{unquote(msg)}")
        end
      end
    end
  end

  defmacro trace(caller, trace_id, msg) do
    if @traceable do
      quote do
        require Logger
        Logger.debug("<#{unquote(caller)}:#{unquote(trace_id)}> #{unquote(msg)}")
      end
    else
      quote do
        # This is useless, just for suppressing unused-variable-warnings.
        if false do
          require Logger
          Logger.debug("<#{unquote(caller)}:#{unquote(trace_id)}> #{unquote(msg)}")
        end
      end
    end
  end
end
