defmodule Base127.InterpolationTest do
  use ExUnit.Case
  alias Base127.Poly
  alias Base127.Interpolation

  # Helper to create points from Elixir integers
  defp pts(list) do
    Enum.map(list, fn {x, y} -> {Num127.from_integer(x), Num127.from_integer(y)} end)
  end

  test "lagrange interpolation satisfies eval(p, xi) == yi" do
    points = pts([{0, 1}, {1, 2}, {2, 5}]) # y = x^2 + 1
    p = Interpolation.lagrange(points)
    
    for {x_i, y_i} <- points do
      assert Poly.eval(p, x_i) == y_i
    end
  end

  test "newton interpolation satisfies eval(p, xi) == yi" do
    points = pts([{0, 1}, {1, 2}, {2, 5}])
    p = Interpolation.newton(points)
    
    for {x_i, y_i} <- points do
      assert Poly.eval(p, x_i) == y_i
    end
  end

  test "lagrange and newton return identical polynomials" do
    points = pts([{10, 5}, {20, 15}, {30, 25}, {40, 35}])
    p_lagrange = Interpolation.lagrange(points)
    p_newton = Interpolation.newton(points)
    
    assert p_lagrange == p_newton
  end

  test "evaluate_at satisfies correctness" do
    points = pts([{0, 1}, {1, 2}, {2, 5}])
    x = Num127.from_integer(3) # x^2 + 1 at 3 is 10
    
    assert Interpolation.evaluate_at(points, x) == Num127.from_integer(10)
    
    # Check at nodal points
    for {x_i, y_i} <- points do
      assert Interpolation.evaluate_at(points, x_i) == y_i
    end
  end

  test "glyph rendering test case: [(0, A), (1, B), (2, C)]" do
    # A=10, B=11, C=12
    points = pts([{0, 10}, {1, 11}, {2, 12}]) # y = x + 10
    p = Interpolation.lagrange(points)
    
    # Verify with Poly.eval
    assert Poly.eval(p, Num127.from_integer(0)) == Num127.from_integer(10)
    assert Poly.eval(p, Num127.from_integer(1)) == Num127.from_integer(11)
    assert Poly.eval(p, Num127.from_integer(2)) == Num127.from_integer(12)
    
    # Render check (descending degree: x + A)
    # 10 is 'A' in Alphabet
    assert Base127.Renderer.render(p) == "x + A"
  end

  test "recover_poly round-trip" do
    original = %Poly{coeffs: pts([{1, 0}, {0, 0}, {1, 0}]) |> Enum.map(&elem(&1, 0))} # x^2 + 1 -> [1, 0, 1]
    # Wait, my pts helper returns {Num127, Num127}. 
    p_orig = %Poly{coeffs: [Num127.from_integer(5), Num127.from_integer(2)]} # 2x + 5
    
    recovered = Interpolation.recover_poly(p_orig, Num127.from_integer(3))
    assert recovered == p_orig
  end

  test "recover_poly field limit error" do
    p = Poly.one()
    assert Interpolation.recover_poly(p, Num127.from_integer(128)) == {:error, :insufficient_field_elements}
  end

  test "duplicate x returns error" do
    points = pts([{1, 1}, {1, 2}])
    assert Interpolation.lagrange(points) == {:error, :duplicate_x}
    assert Interpolation.newton(points) == {:error, :duplicate_x}
    assert Interpolation.evaluate_at(points, Num127.from_integer(0)) == {:error, :duplicate_x}
  end

  test "single point interpolation" do
    points = pts([{5, 10}])
    p = Interpolation.lagrange(points)
    assert p.coeffs == [Num127.from_integer(10)]
    assert Poly.eval(p, Num127.from_integer(5)) == Num127.from_integer(10)
  end

  test "two point interpolation (linear)" do
    points = pts([{0, 0}, {1, 1}]) # y = x
    p = Interpolation.lagrange(points)
    assert p == Poly.identity()
  end
end
