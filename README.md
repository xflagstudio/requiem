# ReQUIem


This library is currently in an experimental phase. We plan to ensure its stability by conducting sufficient interoperability and performance tests in the future.

---

This is Elixir framework for running QuicTransport(WebTransport over QUIC) server.[^1]

- https://w3c.github.io/webtransport/
- https://tools.ietf.org/html/draft-vvv-webtransport-quic-02

This library depends on [cloudflare/quiche](https://github.com/cloudflare/quiche).

**quiche** is written in **Rust**, so you need to prepare Rust compiler to build this library.

ReQUIem requires [Rustler](https://github.com/rusterlium/rustler) to bridge between elixir and rust.

Current **quiche** version is **0.6.0**, and it supports **draft-29** of quic-transport-protocol.
(it also accepts **draft-27** or **draft-28** QUIC frames)


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

Lyo Kato <lyo.kato __at__ gmail.com>
