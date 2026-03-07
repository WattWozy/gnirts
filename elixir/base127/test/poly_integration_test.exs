defmodule Base127.PolyIntegrationTest do
  use ExUnit.Case
  alias Base127.{Parser, Evaluator, Renderer}

  test "identity polynomial x" do
    {:ok, ast} = Parser.parse("x")
    {:ok, val} = Evaluator.eval(ast)
    assert Renderer.render(val) == "x"
  end

  test "polynomial addition" do
    {:ok, ast} = Parser.parse("x + 1")
    {:ok, val} = Evaluator.eval(ast)
    assert Renderer.render(val) == "x + 1"
  end

  test "polynomial multiplication" do
    {:ok, ast} = Parser.parse("(x + 1) * (x + 1)")
    {:ok, val} = Evaluator.eval(ast)
    # (x+1)^2 = x^2 + 2x + 1
    assert Renderer.render(val) == "x^2 + 2x + 1"
  end

  test "polynomial subtraction" do
    {:ok, ast} = Parser.parse("x - x")
    {:ok, val} = Evaluator.eval(ast)
    assert Renderer.render(val) == "0"
  end

  test "polynomial exponentiation" do
    {:ok, ast} = Parser.parse("x ^ 2")
    {:ok, val} = Evaluator.eval(ast)
    assert Renderer.render(val) == "x^2"
  end

  test "polynomial division (quotient)" do
    {:ok, ast} = Parser.parse("(x^2 + 2x + 1) / (x + 1)")
    {:ok, val} = Evaluator.eval(ast)
    assert Renderer.render(val) == "x + 1"
  end

  test "assignment to x is forbidden" do
    assert {:error, "Assignment to reserved keyword 'x' is not allowed"} = Parser.parse("x = 5")
  end

  test "mixed arithmetic promotion" do
    # 2 * x + 3
    {:ok, ast} = Parser.parse("2x + 3")
    {:ok, val} = Evaluator.eval(ast)
    assert Renderer.render(val) == "2x + 3"
  end

  test "complex expression: (x+1)(x-1)" do
    # x^2 - 1. In GF(127), -1 is 126.
    # index 126 is Alphabet.encode(126)
    expected_coeff = Base127.Alphabet.encode(126)
    {:ok, ast} = Parser.parse("(x + 1) * (x - 1)")
    {:ok, val} = Evaluator.eval(ast)
    assert Renderer.render(val) == "x^2 + #{expected_coeff}"
  end
end
