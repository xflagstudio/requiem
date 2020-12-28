defmodule RequiemEchoTest do
  use ExUnit.Case
  doctest RequiemEcho

  test "greets the world" do
    assert RequiemEcho.hello() == :world
  end
end
