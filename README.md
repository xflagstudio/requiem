# [WIP] ReQUIem

QuicTransport (WebTransport over QUIC) framework for Elixir.

This library depends on [cloudflare/quiche](https://github.com/cloudflare/quiche) for QUIC protocol part.

Current **quiche** version is **0.6.0**, and it supports **draft-29** of quic-transport-protocol.
(it also accepts **draft-27** or **draft-28** QUIC frames)

And **quiche** is written in **Rust**, so you need to prepare Rust compiler to build this library.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `requiem` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:requiem, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/requiem](https://hexdocs.pm/requiem).

## Getting Started

https://github.com/xflagstudio/requiem/wiki/GettingStarted

## Handler

https://github.com/xflagstudio/requiem/wiki/Handler

## Configuration

https://github.com/xflagstudio/requiem/wiki/Configuration

## LICENSE

MIT-LICENSE

## Author

Lyo Kaot <lyo.kato __at__ gmail.com>
