defmodule Requiem.Connection do
  require Logger
  require Requiem.Tracer
  use GenServer, restart: :temporary

  alias Requiem.Address
  alias Requiem.AddressTable
  alias Requiem.ClientIndication
  alias Requiem.Config
  alias Requiem.ExceptionGuard
  alias Requiem.ErrorCode
  alias Requiem.ConnectionRegistry
  alias Requiem.ConnectionState
  alias Requiem.QUIC
  alias Requiem.Tracer

  @type t :: %__MODULE__{
          handler: module,
          handler_state: any,
          handler_initialized: boolean,
          allow_address_routing: boolean,
          trace_id: binary,
          web_transport: boolean,
          conn_state: ConnectionState.t(),
          conn: any,
          timer: reference
        }

  defstruct handler: nil,
            handler_state: nil,
            handler_initialized: true,
            allow_address_routing: false,
            trace_id: nil,
            web_transport: true,
            conn_state: nil,
            conn: nil,
            timer: nil

  @spec process_packet(pid, Address.t(), binary) :: :ok
  def process_packet(pid, address, packet) do
    Tracer.trace(__MODULE__, "process_packet")
    GenServer.cast(pid, {:__packet__, address, packet})
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    Tracer.trace(__MODULE__, "start_link:#{Base.encode16(Keyword.fetch!(opts, :dcid))}")
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    state = new(opts)
    Tracer.trace(__MODULE__, state.trace_id, "@init")

    config_ptr = Keyword.fetch!(opts, :config_ptr)
    sender_pid = Keyword.fetch!(opts, :sender_pid)

    case QUIC.Connection.accept(
           config_ptr,
           state.conn_state.dcid,
           state.conn_state.odcid,
           state.conn_state.address.raw,
           sender_pid,
           1024 * 10
         ) do
      {:ok, conn} ->
        Tracer.trace(__MODULE__, state.trace_id, "@acccept: completed")
        Process.flag(:trap_exit, true)

        case ConnectionRegistry.register(
               state.handler,
               state.conn_state.dcid
             ) do
          {:ok, _pid} ->
            Tracer.trace(__MODULE__, state.trace_id, "@init: registered")

            if state.allow_address_routing do
              AddressTable.insert(
                state.handler,
                state.conn_state.address,
                state.conn_state.dcid
              )
            end

            unless state.web_transport do
              send(self(), :__handler_init__)
            end

            {:ok, %{state | conn: conn}}

          {:error, {:already_registered, _pid}} ->
            Tracer.trace(__MODULE__, state.trace_id, "@init: failed registered")
            QUIC.Connection.destroy(conn)
            {:stop, :normal}
        end

      {:error, _reason} ->
        Tracer.trace(__MODULE__, state.trace_id, "failed to accept connection, stop process.")
        {:stop, :normal}
    end
  end

  @impl GenServer
  def handle_call(request, from, %{handler_initialized: true} = state) do
    Tracer.trace(__MODULE__, state.trace_id, "@call: handler_initialized: true")

    ExceptionGuard.guard(
      fn ->
        close(false, :internal_error, :server_error)
        {:reply, :ok, state}
      end,
      fn ->
        case state.handler.handle_call(
               request,
               from,
               state.conn_state,
               state.handler_state
             ) do
          {:reply, resp, %ConnectionState{} = conn_state, handler_state} ->
            {:reply, resp, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:reply, resp, %ConnectionState{} = conn_state, handler_state, timeout}
          when is_integer(timeout) ->
            {:reply, resp, %{state | conn_state: conn_state, handler_state: handler_state},
             timeout}

          {:reply, resp, %ConnectionState{} = conn_state, handler_state, :hibernate} ->
            {:reply, resp, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:noreply, %ConnectionState{} = conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:noreply, %ConnectionState{} = conn_state, handler_state, timeout}
          when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:noreply, %ConnectionState{} = conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.error(
              "<Requiem.Connection:#{self()}> handle_call returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, :internal_error, :server_error)
            {:reply, :ok, state}
        end
      end
    )
  end

  def handle_call(_request, _from, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@call: unknown")
    # just ignore
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:__packet__, _address, packet}, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@packet")

    case QUIC.Connection.on_packet(state.conn, packet) do
      {:ok, next_timeout} ->
        Tracer.trace(
          __MODULE__,
          state.trace_id,
          "@packet: completed, next_timeout: #{next_timeout}"
        )

        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        close(false, :no_error, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        close(false, :internal_error, :server_error)
        {:noreply, state}
    end
  end

  def handle_cast(request, %{handler_initialized: true} = state) do
    Tracer.trace(__MODULE__, state.trace_id, "@cast: handler_initialized: true")

    ExceptionGuard.guard(
      fn ->
        close(false, :internal_error, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.handle_cast(
               request,
               state.conn_state,
               state.handler_state
             ) do
          {:noreply, %ConnectionState{} = conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:noreply, %ConnectionState{} = conn_state, handler_state, timeout}
          when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:noreply, %ConnectionState{} = conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.error(
              "<Requiem.Connection:#{self()}> handle_cast returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, :internal_error, :server_error)
            {:noreply, state}
        end
      end
    )
  end

  def handle_cast(_request, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@cast: unknown")
    # just ignore
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:__handler_init__, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@handler_init")
    handler_init(state.conn, nil, state)
  end

  def handle_info(:__timeout__, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@timeout")

    case QUIC.Connection.on_timeout(state.conn) do
      {:ok, next_timeout} ->
        Tracer.trace(__MODULE__, state.trace_id, "@timeout: done, next_timeout: #{next_timeout}")
        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        Tracer.trace(__MODULE__, state.trace_id, "@timeout: already closed")
        close(false, :no_error, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        Tracer.trace(__MODULE__, state.trace_id, "@timeout: error")
        close(false, :internal_error, :server_error)
        {:noreply, state}
    end
  end

  def handle_info(
        {:__stream_recv__, 2, data},
        %{web_transport: true, handler_initialized: false} = state
      ) do
    Tracer.trace(
      __MODULE__,
      state.trace_id,
      "@stream_recv: handler_initialized: false, web_transport: true, stream_id=2"
    )

    case ClientIndication.from_binary(data) do
      {:ok, client} ->
        handler_init(state.conn, client, state)

      :error ->
        # invalid client indication
        close(false, :protocol_violation, :shutdown)
        {:noreply, state}
    end
  end

  def handle_info(
        {:__stream_recv__, 2, _data},
        %{web_transport: true, handler_initialized: true} = state
      ) do
    # just ignore
    Tracer.trace(
      __MODULE__,
      state.trace_id,
      "@stream_recv: handler_initialized: true, web_transport: true, stream_id=2"
    )

    {:noreply, state}
  end

  def handle_info({:__stream_recv__, stream_id, data}, %{handler_initialized: true} = state) do
    Tracer.trace(__MODULE__, state.trace_id, "@stream_recv: handler_initialized: true")

    ExceptionGuard.guard(
      fn ->
        close(false, :internal_error, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.handle_stream(
               stream_id,
               data,
               state.conn_state,
               state.handler_state
             ) do
          {:ok, %ConnectionState{} = conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:ok, %ConnectionState{} = conn_state, handler_state, timeout}
          when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:ok, %ConnectionState{} = conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.error(
              "<Requiem.Connection:#{self()}> handle_stream returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, :internal_error, :server_error)
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
        close(false, :internal_error, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.handle_dgram(
               data,
               state.conn_state,
               state.handler_state
             ) do
          {:ok, %ConnectionState{} = conn_state, handler_state} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

          {:ok, %ConnectionState{} = conn_state, handler_state, timeout}
          when is_integer(timeout) ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

          {:ok, %ConnectionState{} = conn_state, handler_state, :hibernate} ->
            {:noreply, %{state | conn_state: conn_state, handler_state: handler_state},
             :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            close(true, code, reason)
            {:noreply, state}

          other ->
            Logger.error(
              "<Requiem.Connection:#{self()}> handle_dgram returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, :internal_error, :server_error)
            {:noreply, state}
        end
      end
    )
  end

  def handle_info({:__dgram_recv__, _data}, state) do
    # just ignore
    {:noreply, state}
  end

  def handle_info({:__close__, app, _err, reason}, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@close")

    # TODO set proper error code
    case QUIC.Connection.close(state.conn, app, 0x1, to_string(reason)) do
      {:ok, next_timeout} ->
        Tracer.trace(
          __MODULE__,
          state.trace_id,
          "@close: completed. next_timeout: #{next_timeout}"
        )

        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        Tracer.trace(__MODULE__, state.trace_id, "@close: already closed, set delayed close")
        send(self(), {:__delayed_close__, :normal})
        {:noreply, state}

      {:error, :system_error} ->
        Tracer.trace(__MODULE__, state.trace_id, "@close: error, set delayed close")
        send(self(), {:__delayed_close__, {:shutdown, :system_error}})
        {:noreply, state}
    end
  end

  def handle_info({:__delayed_close__, reason}, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@delayed_closed")
    {:stop, reason, state}
  end

  def handle_info({:__stream_send__, stream_id, data, fin}, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@stream_send")

    case QUIC.Connection.stream_send(state.conn, stream_id, data, fin) do
      {:ok, next_timeout} ->
        Tracer.trace(
          __MODULE__,
          state.trace_id,
          "@stream_send: completed. next_timeout: #{next_timeout}"
        )

        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        Tracer.trace(__MODULE__, state.trace_id, "@stream_send: already closed")
        close(false, :no_error, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        Tracer.trace(__MODULE__, state.trace_id, "@stream_send: error")
        # close(false, 0, :server_error)
        {:noreply, state}
    end
  end

  def handle_info({:__dgram_send__, data}, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@dgram_send")

    case QUIC.Connection.dgram_send(state.conn, data) do
      {:ok, next_timeout} ->
        Tracer.trace(
          __MODULE__,
          state.trace_id,
          "@dgram_send: completed. next_timeout: #{next_timeout}"
        )

        state = reset_conn_timer(state, next_timeout)
        {:noreply, state}

      {:error, :already_closed} ->
        Tracer.trace(__MODULE__, state.trace_id, "@dgram_send: already closed")
        close(false, :no_error, :shutdown)
        {:noreply, state}

      {:error, :system_error} ->
        Tracer.trace(__MODULE__, state.trace_id, "@dgram_send: error")
        # close(false, 0, :server_error)
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, pid, reason}, state) do
    ExceptionGuard.guard(
      fn ->
        close(false, :internal_error, :server_error)
        {:noreply, state}
      end,
      fn ->
        Tracer.trace(__MODULE__, state.trace_id, "@exit: #{inspect(pid)}")

        if ConnectionState.should_delegate_exit?(state.conn_state, pid) do
          new_conn_state = ConnectionState.forget_to_trap_exit(state.conn_state, pid)
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
        close(false, :internal_error, :server_error)
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
      {:noreply, %ConnectionState{} = conn_state, handler_state} ->
        {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}}

      {:noreply, %ConnectionState{} = conn_state, handler_state, timeout}
      when is_integer(timeout) ->
        {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, timeout}

      {:noreply, %ConnectionState{} = conn_state, handler_state, :hibernate} ->
        {:noreply, %{state | conn_state: conn_state, handler_state: handler_state}, :hibernate}

      {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
        close(true, code, reason)
        {:noreply, state}

      other ->
        Logger.error(
          "<Requiem.Connection:#{self()}> handle_info returned unknown pattern: #{inspect(other)}"
        )

        close(false, :internal_error, :server_error)
        {:noreply, state}
    end
  end

  defp handler_init(conn, client, state) do
    ExceptionGuard.guard(
      fn ->
        close(false, :internal_error, :server_error)
        {:noreply, state}
      end,
      fn ->
        case state.handler.init(state.conn_state, client) do
          {:ok, %ConnectionState{} = conn_state, handler_state} ->
            Tracer.trace(__MODULE__, state.trace_id, "@handler.init: completed")

            {:noreply,
             %{
               state
               | conn: conn,
                 conn_state: conn_state,
                 handler_state: handler_state,
                 handler_initialized: true
             }}

          {:ok, %ConnectionState{} = conn_state, handler_state, timeout}
          when is_integer(timeout) ->
            Tracer.trace(__MODULE__, state.trace_id, "@handler.init: completed with timeout")

            {:noreply,
             %{
               state
               | conn: conn,
                 conn_state: conn_state,
                 handler_state: handler_state,
                 handler_initialized: true
             }, timeout}

          {:ok, %ConnectionState{} = conn_state, handler_state, :hibernate} ->
            Tracer.trace(__MODULE__, state.trace_id, "@handler.init: completed with :hibernate")

            {:noreply,
             %{
               state
               | conn: conn,
                 conn_state: conn_state,
                 handler_state: handler_state,
                 handler_initialized: true
             }, :hibernate}

          {:stop, code, reason} when is_integer(code) and is_atom(reason) ->
            Tracer.trace(__MODULE__, state.trace_id, "@handler.init: stop")
            close(true, code, reason)
            {:noreply, %{state | handler_initialized: true}}

          other ->
            Logger.error(
              "<Requiem.Connection:#{self()}> handle_cast returned unknown pattern: #{
                inspect(other)
              }"
            )

            close(false, :internal_error, :server_error)
            {:noreply, %{state | handler_initialized: true}}
        end
      end
    )
  end

  @impl GenServer
  def terminate(reason, state) do
    Tracer.trace(__MODULE__, state.trace_id, "@terminate #{inspect(reason)}")

    state = cancel_conn_timer(state)
    QUIC.Connection.destroy(state.conn)
    state = %{state | conn: nil}

    ConnectionRegistry.unregister(
      state.handler,
      state.conn_state.dcid
    )

    if state.allow_address_routing do
      AddressTable.delete(
        state.handler,
        state.conn_state.address
      )
    end

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

  defp close(app, err, reason) when is_atom(err) do
    close(app, ErrorCode.to_integer(err), reason)
  end

  defp close(app, err, reason) when is_integer(err) do
    send(self(), {:__close__, app, err, reason})
  end

  defp new(opts) do
    dcid = Keyword.fetch!(opts, :dcid)
    scid = Keyword.fetch!(opts, :scid)
    odcid = Keyword.fetch!(opts, :odcid)
    address = Keyword.fetch!(opts, :address)

    trace_id =
      case dcid do
        <<head::binary-size(4), _rest::binary>> -> Base.encode16(head)
        _ -> "----"
      end
    handler = Keyword.fetch!(opts, :handler)

    %__MODULE__{
      handler: handler,
      handler_state: nil,
      handler_initialized: false,
      allow_address_routing: Keyword.fetch!(opts, :allow_address_routing),
      trace_id: trace_id,
      web_transport: Config.get!(handler, :web_transport),
      conn_state: ConnectionState.new(address, dcid, scid, odcid),
      conn: nil,
      timer: nil
    }
  end
end
