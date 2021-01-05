# ReQUIem

## Description

This is Elixir framework for running QuicTransport(WebTransport over QUIC) server.

- https://w3c.github.io/webtransport/
- https://tools.ietf.org/html/draft-vvv-webtransport-quic-02

This library depends on [cloudflare/quiche](https://github.com/cloudflare/quiche).

**quiche** is written in **Rust**, so you need to prepare Rust compiler to build this library.

ReQUIem requires [Rustler](https://github.com/rusterlium/rustler) to bridge between elixir and rust.

Current **quiche** version is **0.6.0**, and it supports **draft-29** of quic-transport-protocol.
(it also accepts **draft-27** or **draft-28** QUIC frames)

- https://tools.ietf.org/html/draft-ietf-quic-transport-29

## Note

This library is currently in an experimental phase.

We plan to ensure its stability by conducting sufficient interoperability and performance tests in the future.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `requiem` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:requiem, "~> 0.1.3"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/requiem](https://hexdocs.pm/requiem).

## Getting Started

### Resource preparation

Prepare a server and set up DNS so that you can access the server with your domain name.

Also, prepare the certificate chain and private key pem file to be used for that domain name.

You can follow the same procedure as when dealing with TLS on a typical web server.

Also, decide the port to use this time, and set the firewall etc. so that you can access the server via that port.

## Define your own handler

First of all, let's define your own handler.

Write the `use Requiem` line as follows.

`lib/my_app/my_handler.ex`

```elixir
defmodule MyApp.MyHandler do
  use Requiem, otp_app: :my_app
end
```

### Configuration

Prepare the config file.
In `config/config.exs` or `config/releases.exs`,
Write as follows.

Make sure that the certificate can be specified via an environment variable.

```elixir
import Config

config :my_app, MyApp.MyHandler,
  host: "0.0,0.0",
  port: 443,
  cert_chain: System.get_env("CERT_FILE"),
  priv_key: System.get_env("PRIV_KEY"),
  initial_max_data: 10_000_000,
  max_udp_payload_size: 1350,
  initial_max_stream_data_bidi_local: 1_000_000,
  initial_max_stream_data_bidi_remote: 1_000_000,
  initial_max_stream_data_uni: 1_000_000,
  initial_max_streams_uni: 10,
  initial_max_streams_bidi: 10,
  disable_active_migration: true,
  enable_early_data: true,
```

Set it like this. There are many more parameters for config, but I won't explain them here. See [Configuration](https://github.com/xflagstudio/requiem/wiki/Configuration) for details.

### Put your handler into your application supervisor

When you start the application, include the handler module that you just created in the child_spec definition of Supervisor.

`lib/my_app/application.ex`

```elixir
defmodule MyApp do
  use Application

  def start(_type, _args) do
    [
      # ...,
      MyApp.MyHandler
    ]
    |> Supervisor.start_link([
      strategy: :one_for_one,
      name: MyApp.Supervisor
    ])
  end
end
```

Now let's launch the application.

```elixir
CERT_FILE=/path/to/cert PRIV_KEY=/path/to/priv_key mix run --no-halt
```

### Handler callbacks

If there are no problems with the config and other settings, this will start the application, but it is of no use at this point.
The reason is that no callback is written in the Handler.

Let's try to implement just printing the sent data to the standard output.

`lib/my_app/my_handler.ex`

```elixir
defmodule MyApp.MyHandler do
  use Requiem, otp_app: :my_app

  @impl Requiem
  def handle_stream(_stream_id, data, conn, state) do
    IO.puts(data)
    {:ok, conn, state}
  end

end
```

If you want to create an echo server that sends data directly back to the recipient, you can write the following

```elixir
defmodule MyApp.MyHandler do
  use Requiem, otp_app: :my_app

  @impl Requiem
  def handle_stream(stream_id, data, conn, state) do
    stream_send(stream_id, data)
    {:ok, conn, state}
  end

end
```


However, this implementation may fail depending on the value of stream_id. See [Stream](https://github.com/xflagstudio/requiem/wiki/Stream) for details.

Let's add a few more things.


```elixir
defmodule MyApp.MyHandler do
  use Requiem, otp_app: :my_app

  @impl Requiem
  def init(conn, client) do
    {:ok, conn, %{}}
  end

  @impl Requiem
  def handle_stream(stream_id, data, conn, state) do
    stream_send(stream_id, data)
    {:ok, conn, state}
  end

  @impl Requiem
  def handle_info(request, conn, state) do
    {:noreply, conn, state}
  end

  @impl Requiem
  def handle_cast(request, conn, state) do
    {:noreply, conn, state}
  end

  @impl Requiem
  def handle_call(request, from, conn, state) do
    {:reply, :ok, conn, state}
  end

  @impl Requiem
  def terminate(_reason, _conn, _state) do
    :ok
  end

end
```

If you are familiar with GenServer, you will see familiar names in the list. There are some parameters that you may not have seen before, such as `conn` and `client`, but other than that, you can probably guess how it behaves.

You can hook initialization and termination processes with `init/2` and `terminate/3`, and receive inter-process messages with `handle_info/3`, `handle_cast/3`, and `handle_call/4`.

In addition, `handle_dgram/3` can handle received datagrams. To send a datagram, use `dgram_send/1`.


```elixir
defmodule MyApp.MyHandler do
  use Requiem, otp_app: :my_app

  @impl Requiem
  def init(conn, client) do
    {:ok, conn, %{}}
  end

  @impl Requiem
  def handle_stream(stream_id, data, conn, state) do
    stream_send(stream_id, data)
    {:ok, conn, state}
  end

  @impl Requiem
  def handle_dgram(data, conn, state) do
    dgram_send(data)
    {:ok, conn, state}
  end

  @impl Requiem
  def handle_info(request, conn, state) do
    {:noreply, conn, state}
  end

  @impl Requiem
  def handle_cast(request, conn, state) do
    {:noreply, conn, state}
  end

  @impl Requiem
  def handle_call(request, from, conn, state) do
    {:reply, :ok, conn, state}
  end

  @impl Requiem
  def terminate(_reason, _conn, _state) do
    :ok
  end

end
```

To use datagrams, you need to set the **enable_dgram** config to true.

```elixir
config :my_app, MyApp.MyHandler,
  host: "0.0,0.0",
  port: 443,
  cert_chain: System.get_env("CERT"),
  priv_key: System.get_env("PRIV_KEY"),
  max_idle_timeout: 50000,
  initial_max_data: 10_000_000,
  max_udp_payload_size: 1350,
  initial_max_stream_data_bidi_local: 1_000_000,
  initial_max_stream_data_bidi_remote: 1_000_000,
  initial_max_stream_data_uni: 1_000_000,
  initial_max_streams_uni: 10,
  initial_max_streams_bidi: 10,
  disable_active_migration: true,
  enable_early_data: true,
  enable_dgram: true
```

Once you have done this, you can open the [WebTransport example page](https://googlechrome.github.io/samples/webtransport/client.html) in Google Chrome and try to interact with it.


For more information on the various callbacks and the various functions that can be called from here, see [Handler](https://github.com/xflagstudio/requiem/wiki/Handler).

## Examples

This repository contains an example project that can be used as a reference.
Check inside the `examples` directory.

## Handler

https://github.com/xflagstudio/requiem/wiki/Handler

## Configuration

https://github.com/xflagstudio/requiem/wiki/Configuration

## LICENSE

MIT-LICENSE

Copyright (C) 2021, [XFLAG Studio (mixi, Inc.)](https://xflag.com/)

See [LICENCE](https://github.com/xflagstudio/requiem/blob/develop/LICENSE) for  details.

## MAINTAINERS

- Lyo Kato <lyo.kato __at__ gmail.com>
- Hidetaka Kojo <hidetaka.kojo __at__ gmail.com>

