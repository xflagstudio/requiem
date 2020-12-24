defmodule RequiemTest.ClientIndicationTest do
  use ExUnit.Case, async: true

  alias Requiem.ClientIndication

  test "client indication" do
    ci = %ClientIndication{
      origin: "localhost",
      path: "/service"
    }

    expect = <<
      0x0000::unsigned-integer-size(16),
      9::unsigned-integer-size(16),
      "localhost"::binary,
      0x0001::unsigned-integer-size(16),
      8::unsigned-integer-size(16),
      "/service"::binary
    >>

    bin = ClientIndication.to_binary(ci)
    assert bin == expect
    {:ok, result} = ClientIndication.from_binary(bin)
    assert result.origin == "localhost"
    assert result.path == "/service"

    assert ClientIndication.from_binary(<<"bad-format"::binary>>) == :error
  end
end
