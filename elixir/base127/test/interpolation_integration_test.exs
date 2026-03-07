defmodule Base127.InterpolationIntegrationTest do
  use ExUnit.Case
  alias Base127.Parser
  alias Base127.Evaluator
  alias Base127.Renderer
  alias Base127.Poly

  test "interpolate keyword in parser and evaluator" do
    # interpolate [(0, 1), (1, 2), (2, 5)] should be x^2 + 1
    code = "interpolate [(0, 1), (1, 2), (2, 5)]"
    {:ok, ast} = Parser.parse(code)
    {:ok, result} = Evaluator.eval(ast)
    
    assert %Poly{} = result
    assert Renderer.render(result) == "x^2 + 1"
  end

  test "interpolate at value" do
    # interpolate [(0, 1), (1, 2), (2, 5)] at 3 should be 10
    # 3 in Alphabet is '3', 10 is 'A' (assuming default alphabet)
    code = "interpolate [(0, 1), (1, 2), (2, 5)] at 3"
    {:ok, ast} = Parser.parse(code)
    {:ok, result} = Evaluator.eval(ast)
    
    assert is_list(result) # Num127
    assert Renderer.render(result) == "A"
  end

  test "interpolate with glyphs" do
    # [(0, A), (1, B), (2, C)] -> x + A
    code = "interpolate [(0, A), (1, B), (2, C)]"
    {:ok, ast} = Parser.parse(code)
    {:ok, result} = Evaluator.eval(ast)
    
    assert Renderer.render(result) == "x + A"
  end

  test "complex expressions in interpolate points" do
    code = "interpolate [(0, 1+1), (1, 2*2)]" # (0, 2), (1, 4) -> 2x + 2
    {:ok, ast} = Parser.parse(code)
    {:ok, result} = Evaluator.eval(ast)
    
    assert Renderer.render(result) == "2x + 2"
  end
end
