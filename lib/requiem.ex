defmodule Requiem do
  @moduledoc """
  Documentation for `Requiem`.
  """

  @type terminate_reason :: :normal | :shutdown | {:shutdown, term} | term

  @callback init(conn :: Requiem.ConnectionState.t(), client :: Requiem.ClientIndication.t()) ::
              {:ok, Requiem.ConnectionState.t(), any}
              | {:ok, Requiem.ConnectionState.t(), any, timeout | :hibernate}
              | {:stop, non_neg_integer, atom}

  @callback handle_call(
              request :: term,
              from :: pid,
              conn :: Requiem.ConnectionState.t(),
              state :: any
            ) ::
              {:noreply, Requiem.ConnectionState.t(), any}
              | {:noreply, Requiem.ConnectionState.t(), any, timeout | :hibernate}
              | {:reply, any, Requiem.ConnectionState.t(), any}
              | {:reply, any, Requiem.ConnectionState.t(), any, timeout | :hibernate}
              | {:stop, non_neg_integer, atom}

  @callback handle_info(
              request :: term,
              conn :: Requiem.ConnectionState.t(),
              state :: any
            ) ::
              {:noreply, Requiem.ConnectionState.t(), any}
              | {:noreply, Requiem.ConnectionState.t(), any, timeout | :hibernate}
              | {:stop, non_neg_integer, atom}

  @callback handle_cast(
              request :: term,
              conn :: Requiem.ConnectionState.t(),
              state :: any
            ) ::
              {:noreply, Requiem.ConnectionState.t(), any}
              | {:noreply, Requiem.ConnectionState.t(), any, timeout | :hibernate}
              | {:stop, non_neg_integer, atom}

  @callback handle_stream(
              stream_id :: non_neg_integer,
              data :: binary,
              conn :: Requiem.ConnectionState.t(),
              state :: any
            ) ::
              {:ok, Requiem.ConnectionState.t(), any}
              | {:ok, Requiem.ConnectionState.t(), any, timeout | :hibernate}
              | {:stop, non_neg_integer, atom}

  @callback handle_dgram(
              data :: binary,
              conn :: Requiem.ConnectionState.t(),
              state :: any
            ) ::
              {:ok, Requiem.ConnectionState.t(), any}
              | {:ok, Requiem.ConnectionState.t(), any, timeout | :hibernate}
              | {:stop, non_neg_integer, atom}

  @callback terminate(
              reason :: terminate_reason,
              conn :: Requiem.ConnectionState.t(),
              state :: any
            ) :: any

  defmacro __using__(opts \\ []) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Requiem

      import Requiem.ConnectionState, only: [trap_exit: 2]

      @spec close() :: no_return
      def close(), do: send(self(), {:__close__, false, :no_error, :shutdown})

      @spec close(non_neg_integer, atom) :: no_return
      def close(code, reason), do: send(self(), {:__close__, true, code, reason})

      @spec stream_send(non_neg_integer, binary) :: no_return
      def stream_send(stream_id, data) do
        if Requiem.StreamId.is_writable?(stream_id) do
          send(self(), {:__stream_send__, stream_id, data})
        else
          Logger.error(
            "<Requiem.Connection> You can't send data on this stream[stream_id: #{stream_id}]. This stream is not writable."
          )
        end
      end

      @spec dgram_send(binary) :: no_return
      def dgram_send(data),
        do: send(self(), {:__dgram_send__, data})

      @otp_app Keyword.fetch!(opts, :otp_app)

      @impl Requiem
      def init(conn, client), do: {:ok, conn, %{}}

      @impl Requiem
      def handle_info(_event, conn, state), do: {:noreply, conn, state}

      @impl Requiem
      def handle_cast(_event, conn, state), do: {:noreply, conn, state}

      @impl Requiem
      def handle_call(_event, _from, conn, state), do: {:reply, :ok, conn, state}

      @impl Requiem
      def handle_stream(_stream_id, _data, conn, state), do: {:ok, conn, state}

      @impl Requiem
      def handle_dgram(_data, conn, state), do: {:ok, conn, state}

      @impl Requiem
      def terminate(_reason, _conn, _state), do: :ok

      defoverridable init: 2,
                     handle_info: 3,
                     handle_cast: 3,
                     handle_call: 4,
                     handle_stream: 4,
                     handle_dgram: 3,
                     terminate: 3

      @spec child_spec(any) :: Supervisor.child_spec()
      def child_spec(_opts) do
        Requiem.Supervisor.child_spec(__MODULE__, @otp_app)
      end
    end
  end
end
