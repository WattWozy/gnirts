defmodule Base127.RuntimeTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Base127.{Alphabet, Parser, Evaluator, Renderer}

  property "render(parse(render(x))) == render(x) for random Num127" do
    check all digits <- list_of(integer(0..126), min_length: 1, max_length: 20) do
      val = Num127.normalize(digits)
      rendered = Renderer.render(val)
      {:ok, parsed_ast} = Parser.parse(rendered)
      {:ok, evaluated_val} = Evaluator.eval(parsed_ast)
      assert Renderer.render(evaluated_val) == rendered
    end
  end

  property "commutativity: eval(a + b) == eval(b + a)" do
    check all a_digits <- list_of(integer(0..126), min_length: 1, max_length: 10),
              b_digits <- list_of(integer(0..126), min_length: 1, max_length: 10) do
      a_str = Renderer.render(Num127.normalize(a_digits))
      b_str = Renderer.render(Num127.normalize(b_digits))
      
      expr1 = "#{a_str} + #{b_str}"
      expr2 = "#{b_str} + #{a_str}"
      
      {:ok, ast1} = Parser.parse(expr1)
      {:ok, ast2} = Parser.parse(expr2)
      
      {:ok, val1} = Evaluator.eval(ast1)
      {:ok, val2} = Evaluator.eval(ast2)
      
      assert Renderer.render(val1) == Renderer.render(val2)
    end
  end

  test "rational results are in lowest terms" do
    # 2/4 should be 1/2
    # In Base-127: 2/4
    # 2 is [2], 4 is [4]. GCD is [2].
    {:ok, ast} = Parser.parse("2 / 4")
    {:ok, val} = Evaluator.eval(ast)
    # 1/2 rendered
    assert Renderer.render(val) == "1/2"
  end

  test "decimal approximation" do
    # 1/3 in base 127
    # 1 / 3 = 0. (1*127/3) ...
    # 127 / 3 = 42 rem 1
    # So 0.424242...
    {:ok, ast} = Parser.parse("1 / 3")
    {:ok, val} = Evaluator.eval(ast)
    # Digit 42 is 'G' in our alphabet (0..9, A..Z, a..z: A=10, Z=35, a=36, g=42? No, a=36, b=37, c=38, d=39, e=40, f=41, g=42!)
    # Wait, G is uppercase? 0-9(10), A-Z(26) -> A is 10, Z is 35. 
    # alphabet: 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ
    # G is index 16.
    # a is index 36. g is index 42.
    # So 0.g g g ...
    assert Renderer.approx(val, 3) == "0.ggg"
  end
end
