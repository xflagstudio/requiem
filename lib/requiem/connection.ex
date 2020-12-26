defmodule Requiem.Connection do
  require Logger
  use GenServer, restart: :temporary

  defmodule ExceptionGuard do
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

  @type t :: %__MODULE__{
          handler: module,
          handler_state: any,
          handler_initialized: boolean,
          transport: module,
          trace: boolean,
          web_transport: boolean,
          conn_state: Requiem.ConnectionState.t(),
          conn: any,
          timer: reference
        }

  defstruct handler: nil,
            handler_state: nil,
            handler_initialized: true,
            transport: nil,
            trace: false,
            web_transport: true,
            conn_state: nil,
            conn: nil,
            timer: nil

  @spec process_packet(pid, RequiemAddress.t(), binary) :: :ok
  def process_packet(pid, address, packet) do
    Logger.debug("Connection:process_packet")
    GenServer.cast(pid, {:__packet__, address, packet})
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    Logger.debug("Connection:start_link:#{Base.encode16(Keyword.fetch!(opts, :dcid))}")
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    state = new(opts)
    trace("@init", state)

    Process.flag(:trap_exit, true)

    case Requiem.ConnectionRegistry.register(
           state.handler,
           state.conn_state.dcid
         ) do
      {:ok, _pid} ->
        trace("@init: registered", state)

        Requiem.AddressTable.insert(
          state.handler,
          state.conn_state.address,
          state.conn_state.dcid
        )

        send(self(), :__accept__)
        {:ok, state}

      {:error, {:already_registered, _pid}} ->
        trace("@init: failed registered", state)
        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_call(request, from, %{handler_initialized: true} = state) do
    trace("@call: handler_initialized: true", state)

    ExceptionGuard.guard(
      fn ->
        close(false, 0, :server_error)
        {:reply, :ok, state}
      end,
      fn ->
        case state.handler.handle_call(
               request,
               from,
               state.conn_state,
               state.handler_state
             ) do
          {:reply, resp, conn_state, handler_state} ->
            {:reply, resp, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:reply, resp, conn_state, handler_state, timeout} when is_integer(timeout) ->
            {:reply, resp, %{state | conn_state: conn_state, handler_state: handler_state},
             timeout}

          {:reply, resp, conn_state, handler_state, :hibernate} ->
            {:reply, resp, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:noreply, conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:noreply, conn_state, handler_state, timeout} when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:noreply, conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.warn(
              "<Requiem.Connection:#{self()}> handle_call returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, 0, :server_error)
            {:reply, :ok, state}
        end
      end
    )
  end

  def handle_call(_request, _from, state) do
    trace("@call: unknown", state)
    # just ignore
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:__packet__, _address, packet}, state) do
    trace("@packet", state)

    case Requiem.QUIC.Connection.on_packet(state.conn, packet) do
      {:ok, next_timeout} ->
        trace("@packet: completed, next_timeout: #{next_timeout}", state)
        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        close(false, 0, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        close(false, 0, :server_error)
        {:noreply, state}
    end
  end

  def handle_cast(request, %{handler_initialized: true} = state) do
    trace("@cast: handler_initialized: true", state)

    ExceptionGuard.guard(
      fn ->
        close(false, 0, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.handle_cast(
               request,
               state.conn_state,
               state.handler_state
             ) do
          {:noreply, conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:noreply, conn_state, handler_state, timeout} when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:noreply, conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.warn(
              "<Requiem.Connection:#{self()}> handle_cast returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, 0, :server_error)
            {:noreply, state}
        end
      end
    )
  end

  def handle_cast(_request, state) do
    trace("@cast: unknown", state)
    # just ignore
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:__accept__, state) do
    trace("@acccept", state)

    case Requiem.QUIC.Connection.accept(
           state.handler,
           state.conn_state.scid,
           state.conn_state.odcid
         ) do
      {:ok, conn} ->
        trace("@acccept: completed", state)

        if state.web_transport do
          # just set conn, don't call handler_init here
          {:noreply, %{state | conn: conn}}
        else
          trace("@acccept: handler.init", state)
          handler_init(conn, nil, state)
        end

      {:error, _reason} ->
        if state.trace do
          Logger.info("<Requiem.Connection:#{self()}> failed to accept connection, stop process.")
        end

        {:stop, :normal, state}
    end
  end

  def handle_info(:__timeout__, state) do
    trace("@timeout", state)

    case Requiem.QUIC.Connection.on_timeout(state.conn) do
      {:ok, next_timeout} ->
        trace("@timeout: done, next_timeout: #{next_timeout}", state)
        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        trace("@timeout: already closed", state)
        close(false, 0, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        trace("@timeout: error", state)
        close(false, 0, :server_error)
        {:noreply, state}
    end
  end

  def handle_info(
        {:__stream_recv__, 2, data},
        %{web_transport: true, handler_initialized: false} = state
      ) do
    trace("@stream_recv: handler_initialized: false, web_transport: true, stream_id=2", state)

    case Requiem.ClientIndication.from_binary(data) do
      {:ok, client} ->
        handler_init(state.conn, client, state)

      :error ->
        # invalid client indication
        close(false, 0, :shutdown)
        {:noreply, state}
    end
  end

  def handle_info(
        {:__stream_recv__, 2, _data},
        %{web_transport: true, handler_initialized: true} = state
      ) do
    # just ignore
    trace("@stream_recv: handler_initialized: true, web_transport: true, stream_id=2", state)
    {:noreply, state}
  end

  def handle_info({:__stream_recv__, stream_id, data}, %{handler_initialized: true} = state) do
    trace("@stream_recv: handler_initialized: true", state)

    ExceptionGuard.guard(
      fn ->
        close(false, 0, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.handle_stream(
               stream_id,
               data,
               state.conn_state,
               state.handler_state
             ) do
          {:ok, conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:ok, conn_state, handler_state, timeout} when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:ok, conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.warn(
              "<Requiem.Connection:#{self()}> handle_stream returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, 0, :server_error)
            {:noreply, state}
        end
      end
    )
  end

  def handle_info({:__stream_recv__, _stream_id, _data}, state) do
    # just ignore
    {:noreply, state}
  end

  def handle_info({:__dgram_recv__, data}, %{handler_initialized: true} = state) do
    ExceptionGuard.guard(
      fn ->
        close(false, 0, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.handle_dgram(
               data,
               state.conn_state,
               state.handler_state
             ) do
          {:ok, conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:ok, conn_state, handler_state, timeout} when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:ok, conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.warn(
              "<Requiem.Connection:#{self()}> handle_dgram returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, 0, :server_error)
            {:noreply, state}
        end
      end
    )
  end

  def handle_info({:__dgram_recv__, _data}, state) do
    # just ignore
    {:noreply, state}
  end

  def handle_info({:__close__, app, err, reason}, state) do
    trace("@close", state)

    case Requiem.QUIC.Connection.close(state.conn, app, err, to_string(reason)) do
      :ok ->
        trace("@close: completed, set delayed close", state)
        send(self(), {:__delayed_close__, reason})

      {:error, :already_closed} ->
        trace("@close: already closed, set delayed close", state)
        send(self(), {:__delayed_close__, :normal})

      {:error, :system_error} ->
        trace("@close: error, set delayed close", state)
        send(self(), {:__delayed_close__, {:shutdown, :system_error}})
    end

    {:noreply, state}
  end

  def handle_info({:__delayed_close__, reason}, state) do
    trace("@delayed_closed", state)
    {:stop, reason, state}
  end

  def handle_info({:__stream_send__, stream_id, data}, state) do
    trace("@stream_send", state)

    case Requiem.QUIC.Connection.stream_send(state.conn, stream_id, data) do
      {:ok, next_timeout} ->
        trace("@stream_send: completed. next_timeout: #{next_timeout}", state)
        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        trace("@stream_send: already closed", state)
        close(false, 0, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        trace("@stream_send: error", state)
        close(false, 0, :server_error)
        {:noreply, state}
    end
  end

  def handle_info({:__dgram_send__, data}, state) do
    trace("@dgram_send", state)

    case Requiem.QUIC.Connection.dgram_send(state.conn, data) do
      {:ok, next_timeout} ->
        trace("@dgram_send: completed. next_timeout: #{next_timeout}", state)
        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        trace("@dgram_send: already closed", state)
        close(false, 0, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        trace("@dgram_send: error", state)
        close(false, 0, :server_error)
        {:noreply, state}
    end
  end

  def handle_info({:__drain__, data}, state) do
    trace("@drain", state)

    state.transport.send(
      state.handler,
      state.conn_state.address,
      data
    )

    {:noreply, state}
  end

  def handle_info({:EXIT, pid, reason}, state) do
    ExceptionGuard.guard(
      fn ->
        close(false, 0, :server_error)
        {:noreply, state}
      end,
      fn ->
        trace("@exit: #{inspect(pid)}", state)

        if Requiem.ConnectionState.should_delegate_exit?(state.conn_state, pid) do
          new_conn_state = Requiem.ConnectionState.forget_to_trap_exit(state.conn_state, pid)
          new_state = %{state | conn_state: new_conn_state}
          handler_handle_info({:EXIT, pid, reason}, new_state)
        else
          {:noreply, state}
        end
      end
    )
  end

  def handle_info(request, %{handler_initialized: true} = state) do
    ExceptionGuard.guard(
      fn ->
        close(false, 0, :server_error)
        {:noreply, state}
      end,
      fn ->
        handler_handle_info(request, state)
      end
    )
  end

  def handle_info(_request, state) do
    # just ignore
    {:noreply, state}
  end

  defp handler_handle_info(request, state) do
    case state.handler.handle_info(
           request,
           state.conn_state,
           state.handler_state
         ) do
      {:noreply, conn_state, handler_state} ->
        {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

      {:noreply, conn_state, handler_state, timeout} when is_integer(timeout) ->
        {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

      {:noreply, conn_state, handler_state, :hibernate} ->
        {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, :hibernate}

      {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
        close(true, code, reason)
        {:noreply, state}

      other ->
        Logger.warn(
          "<Requiem.Connection:#{self()}> handle_info returned unknown pattern: #{inspect(other)}"
        )

        close(false, 0, :server_error)
        {:noreply, state}
    end
  end

  defp handler_init(conn, client, state) do
    ExceptionGuard.guard(
      fn ->
        close(false, 0, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.init(state.conn_state, client) do
          {:ok, conn_state, handler_state} ->
            trace("@handler.init: completed", state)

            {:noreply,
             %{
               state
               | conn: conn,
                 conn_state: conn_state,
                 handler_state: handler_state,
                 handler_initialized: true
             }}

          {:ok, conn_state, handler_state, timeout} when is_integer(timeout) ->
            trace("@handler.init: completed with timeout", state)

            {:noreply,
             %{
               state
               | conn: conn,
                 conn_state: conn_state,
                 handler_state: handler_state,
                 handler_initialized: true
             }, timeout}

          {:ok, conn_state, handler_state, :hibernate} ->
            trace("@handler.init: completed with :hibernate", state)

            {:noreply,
             %{
               state
               | conn: conn,
                 conn_state: conn_state,
                 handler_state: handler_state,
                 handler_initialized: true
             }, :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            trace("@handler.init: stop", state)
            close(true, code, reason)
            {:noreply, %{state | handler_initialized: true}}

          other ->
            Logger.warn(
              "<Requiem.Connection:#{self()}> handle_cast returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, 0, :server_error)
            {:noreply, %{state | handler_initialized: true}}
        end
      end
    )
  end

  @impl GenServer
  def terminate(reason, state) do
    trace("@terminate #{inspect(reason)}", state)

    state = cancel_conn_timer(state)

    Requiem.ConnectionRegistry.unregister(
      state.handler,
      state.conn_state.dcid
    )

    Requiem.AddressTable.delete(
      state.handler,
      state.conn_state.address
    )

    if state.handler_initialized do
      ExceptionGuard.guard(
        fn -> :ok end,
        fn ->
          state.handler.terminate(
            reason,
            state.conn_state,
            state.handler_state
          )

          :ok
        end
      )
    end
  end

  defp reset_conn_timer(state, timeout) do
    state
    |> cancel_conn_timer()
    |> start_conn_timer(timeout)
  end

  defp start_conn_timer(state, timeout) do
    timer = Process.send_after(self(), :__timeout__, timeout)
    %{state | timer: timer}
  end

  defp cancel_conn_timer(state) do
    case state.timer do
      nil ->
        state

      timer ->
        Process.cancel_timer(timer)
        %{state | timer: nil}
    end
  end

  @spec close(boolean, non_neg_integer, atom) :: no_return
  defp close(app, err, reason) do
    send(self(), {:__close__, app, err, reason})
  end

  def trace(message, %__MODULE__{trace: true} = state) do
    dcid = case state.conn_state.dcid do
      << head :: binary-size(4), _rest :: binary >> -> head
      _ -> "----"
    end
    Logger.debug(
      "<Requiem.Connection:#{inspect(self())}:#{Base.encode16(dcid)}> #{message}"
    )

    :ok
  end

  def trace(_message, _state) do
    :ok
  end

  defp new(opts) do
    dcid = Keyword.fetch!(opts, :dcid)
    scid = Keyword.fetch!(opts, :scid)
    odcid = Keyword.fetch!(opts, :odcid)
    address = Keyword.fetch!(opts, :address)

    %__MODULE__{
      handler: Keyword.fetch!(opts, :handler),
      handler_state: nil,
      handler_initialized: false,
      transport: Keyword.fetch!(opts, :transport),
      trace: Keyword.get(opts, :trace, false),
      web_transport: Keyword.get(opts, :web_transport, true),
      conn_state: Requiem.ConnectionState.new(address, dcid, scid, odcid),
      conn: nil,
      timer: nil
    }
  end
end
