defmodule HackatticTest do
  use ExUnit.Case
  doctest Hackattic

  test "greets the world" do
    assert Hackattic.hello() == :world
  end
end
