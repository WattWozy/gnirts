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

  test "exponentiation basics" do
    # 2^3 = 8
    {:ok, ast} = Parser.parse("2 ^ 3")
    {:ok, val} = Evaluator.eval(ast)
    if Renderer.render(val) != "8" do
      File.write!("FAILDATA_BASICS.txt", "2^3 expected 8, got #{Renderer.render(val)}")
    end
    assert Renderer.render(val) == "8"

    # (1/2)^2 = 1/4
    {:ok, ast} = Parser.parse("(1/2) ^ 2")
    {:ok, val} = Evaluator.eval(ast)
    if Renderer.render(val) != "1/4" do
      File.write!("FAILDATA_BASICS.txt", "(1/2)^2 expected 1/4, got #{Renderer.render(val)}", [:append])
    end
    assert Renderer.render(val) == "1/4"

    # 2^-1 = 1/2
    {:ok, ast} = Parser.parse("2 ^ -1")
    {:ok, val} = Evaluator.eval(ast)
    if Renderer.render(val) != "1/2" do
      File.write!("FAILDATA_BASICS.txt", "2^-1 expected 1/2, got #{Renderer.render(val)}", [:append])
    end
    assert Renderer.render(val) == "1/2"

    # 10^2 = 100
    # In base 127: 100 is glyph index 100.
    # index 100 is greek lowercase ψ? No. glyph list...
    # index 100 is in geometric or alpha...
    # Alphabet: 0..9, A..Z, a..z: A=10, Z=35, a=36, z=61.
    # 62..85: greek lower. 86..109: greek upper.
    # 100 is lowercase Greek? No, 86 is upper starts. So 100 is in upper.
    # 100 - 86 = 14. 15th upper Greek? 
    # Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο
    # index 14 is Ο (Omicron upper).
    # Wait, my count above was slightly different. Let's just evaluate and see!
    {:ok, ast} = Parser.parse("10^2")
    {:ok, val} = Evaluator.eval(ast)
    # 10 in base 127 is 127. 10^2 = 127^2 = 16129 = [0, 0, 1] -> "100"
    rendered = Renderer.render(val)
    if rendered != "100" do
      File.write!("FAILDATA_BASICS.txt", "10^2 expected 100, got #{rendered}", [:append])
    end
    assert rendered == "100"
  end

  test "exponentiation right-associativity" do
    # 2^3^2 = 2^(3^2) = 2^9 = 512
    {:ok, ast} = Parser.parse("2 ^ 3 ^ 2")
    {:ok, val} = Evaluator.eval(ast)
    # 512 = 4*127 + 4 = [4, 4] reversed [4, 4] -> "44"
    if Renderer.render(val) != "44" do
      File.write!("FAILDATA_ASSOC.txt", "2^3^2 expected 44, got #{Renderer.render(val)}")
    end
    assert Renderer.render(val) == "44"
  end

  test "rational results are in lowest terms" do
    # 2/4 should be 1/2
    # In Base-127: 2/4
    # 2 is [2], 4 is [4]. GCD is [2].
    {:ok, ast} = Parser.parse("2 / 4")
    {:ok, val} = Evaluator.eval(ast)
    # 1/2 rendered
    if Renderer.render(val) != "1/2" do
      File.write!("FAILDATA_LOWEST.txt", "2/4 expected 1/2, got #{Renderer.render(val)}")
    end
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
    if Renderer.approx(val, 3) != "0.ggg" do
      File.write!("FAILDATA_APPROX.txt", "1/3 expected 0.ggg, got #{Renderer.approx(val, 3)}")
    end
    assert Renderer.approx(val, 3) == "0.ggg"
  end
end
