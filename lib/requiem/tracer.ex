defmodule Requiem.Tracer do
  @traceable Application.compile_env(:requiem, :trace, false)
  defmacro trace(caller, msg) do
    if @traceable do
      quote do
        Logger.debug("<#{unquote(caller)}> #{unquote(msg)}")
      end
    end
  end

  defmacro trace(caller, trace_id, msg) do
    if @traceable do
      quote do
        Logger.debug("<#{unquote(caller)}:#{unquote(trace_id)}> #{unquote(msg)}")
      end
    end
  end

  defmacro trace_fn(caller, trace_id, msg) do
    if @traceable do
      quote do
        Logger.debug("<#{unquote(caller)}:#{unquote(trace_id)}> #{unquote(msg)()}")
      end
    end
  end
end
