defmodule Base127.MeasureTest do
  use ExUnit.Case
  alias Base127.Poly
  alias Base127.Interpolation
  alias Base127.Measure

  # ---------------------------------------------------------------------------
  # Helpers — all values created through project primitives
  # ---------------------------------------------------------------------------

  # Build a %Poly{} from an integer-coefficient list (ascending degree order).
  defp poly(int_coeffs) do
    %Poly{coeffs: Enum.map(int_coeffs, &Num127.from_integer/1)} |> Poly.normalize()
  end

  # Convert an Elixir integer list to a list of {Num127, Num127} points.
  defp pts(pairs) do
    Enum.map(pairs, fn {x, y} -> {Num127.from_integer(x), Num127.from_integer(y)} end)
  end

  # Shorthand for Num127 values from integers.
  defp n(i), do: Num127.from_integer(i)

  # Compare two Num127 values.
  defp num_lte?(a, b), do: Num127.compare(a, b) in [:lt, :eq]

  # ── Measure.degree/1 ────────────────────────────────────────────────────────

  describe "degree/1" do
    test "zero polynomial returns {:undefined}" do
      assert Measure.degree(Poly.zero()) == {:undefined}
    end

    test "constant nonzero polynomial has degree Num127.zero" do
      # single coefficient [1] → degree 0
      assert Measure.degree(%Poly{coeffs: [n(1)]}) == n(0)
    end

    test "Poly.one has degree Num127.zero" do
      assert Measure.degree(Poly.one()) == n(0)
    end

    test "linear polynomial x has degree 1" do
      # identity = [0, 1] coeffs → degree 1
      assert Measure.degree(Poly.identity()) == n(1)
    end

    test "x^2 has degree 2" do
      assert Measure.degree(poly([0, 0, 1])) == n(2)
    end

    test "x^2 + 1 has degree 2" do
      assert Measure.degree(poly([1, 0, 1])) == n(2)
    end

    test "degree tracks last nonzero, ignores trailing zeros" do
      # poly([1, 0, 0]) normalises to [1] → degree 0
      p = poly([1, 0, 0])
      assert Measure.degree(p) == n(0)
    end
  end

  # ── Measure.roots/1 ─────────────────────────────────────────────────────────

  describe "roots/1" do
    test "zero polynomial returns {:error, :zero_poly}" do
      assert Measure.roots(Poly.zero()) == {:error, :zero_poly}
    end

    test "constant nonzero polynomial has no roots" do
      assert Measure.roots(Poly.one()) == []
    end

    test "x has exactly one root: 0" do
      assert Measure.roots(Poly.identity()) == [n(0)]
    end

    test "x^2 - 1 has roots 1 and 126 (≡ -1 mod 127)" do
      # x^2 - 1  coeffs = [-1, 0, 1] = [126, 0, 1] in GF(127)
      p = poly([126, 0, 1])
      roots = Measure.roots(p)
      assert n(1) in roots
      assert n(126) in roots
      assert length(roots) == 2
    end

    test "root 126 is the glyph ▼ (value 126 ≡ -1 mod 127)" do
      # Confirm the renderer renders it correctly as ▼
      p = poly([126, 0, 1])
      roots = Measure.roots(p)
      rendered = Enum.map(roots, &Base127.Renderer.render/1)
      assert "▼" in rendered
      assert "1" in rendered
    end

    test "x^2 has a repeated root at 0" do
      p = poly([0, 0, 1])
      assert Measure.roots(p) == [n(0)]
    end

    test "x^127 - x has all 127 field elements as roots (Fermat's Little Theorem)" do
      # x^127 - x = 1·x^127 + (-1)·x  i.e. coefficients:
      # index 0 (constant) = 0, index 1 (x term) = 126 (-1 mod 127),
      # indices 2..126 = 0, index 127 = 1
      const_coeff = n(0)
      neg_x_coeff = n(126)    # -1 ≡ 126 mod 127
      zero_coeffs = List.duplicate(n(0), 125)  # indices 2..126
      high_coeff  = n(1)      # coefficient of x^127
      coeffs = [const_coeff, neg_x_coeff] ++ zero_coeffs ++ [high_coeff]
      p = Poly.normalize(%Poly{coeffs: coeffs})

      roots = Measure.roots(p)
      assert length(roots) == 127

      # Every field element 0..126 must appear.
      expected = Enum.map(0..126, &n/1)
      assert Enum.sort(roots) == Enum.sort(expected)
    end

    test "nonzero degree-n polynomial has at most n roots (postcondition)" do
      # Check for several polynomials.
      polys = [
        poly([1, 1]),            # x + 1,  degree 1 → at most 1 root
        poly([126, 0, 1]),       # x^2 - 1, degree 2 → at most 2 roots
        poly([0, 0, 1]),         # x^2,     degree 2 → at most 2 roots
        poly([1, 0, 0, 1]),      # x^3 + 1, degree 3 → at most 3 roots
      ]
      for p <- polys do
        deg = Measure.degree(p)
        rc  = Measure.root_count(p)
        # rc <= deg using Num127.compare
        assert num_lte?(rc, deg), "root_count #{inspect rc} > degree #{inspect deg} for #{inspect p}"
      end
    end
  end

  # ── Measure.root_count/1 ────────────────────────────────────────────────────

  describe "root_count/1" do
    test "zero polynomial returns error" do
      assert Measure.root_count(Poly.zero()) == {:error, :zero_poly}
    end

    test "x has root_count 1" do
      assert Measure.root_count(Poly.identity()) == n(1)
    end

    test "x^2 - 1 has root_count 2" do
      assert Measure.root_count(poly([126, 0, 1])) == n(2)
    end

    test "x^127 - x has root_count 127" do
      const_coeff    = n(0)
      neg_x_coeff    = n(126)  # -1 mod 127
      zero_coeffs    = List.duplicate(n(0), 125)
      high_coeff     = n(1)
      coeffs = [const_coeff, neg_x_coeff] ++ zero_coeffs ++ [high_coeff]
      p = Poly.normalize(%Poly{coeffs: coeffs})
      assert Measure.root_count(p) == n(127)
    end
  end

  # ── Measure.fit_count/2 ──────────────────────────────────────────────────────

  describe "fit_count/2" do
    test "empty points list returns Num127.zero" do
      assert Measure.fit_count(Poly.identity(), []) == n(0)
    end

    test "perfect fit: lagrange interpolant scores n out of n" do
      points = pts([{0, 1}, {1, 2}, {2, 5}])
      p = Interpolation.lagrange(points)
      count = Measure.fit_count(p, points)
      assert count == n(3)
    end

    test "exact fit for 5-point interpolant" do
      points = pts([{0, 0}, {1, 1}, {2, 4}, {3, 9}, {4, 16}])
      p = Interpolation.lagrange(points)
      count = Measure.fit_count(p, points)
      assert count == n(5)
    end

    test "zero poly scores 0 on nonzero y points" do
      points = pts([{0, 1}, {1, 2}])
      count = Measure.fit_count(Poly.zero(), points)
      assert count == n(0)
    end

    test "partial fit: only matching points are counted" do
      # p = constant 5; points have y=5 for x=0 and y=7 for x=1
      p = poly([5])
      points = [{n(0), n(5)}, {n(1), n(7)}]
      assert Measure.fit_count(p, points) == n(1)
    end
  end

  # ── Measure.fit_ratio/2 ──────────────────────────────────────────────────────

  describe "fit_ratio/2" do
    test "perfect fit returns {n, n} which Num127.exact_div reduces to {1, 1}" do
      points = pts([{0, 1}, {1, 2}, {2, 5}])
      p = Interpolation.lagrange(points)
      {count, total} = Measure.fit_ratio(p, points)
      # exact_div(3, 3) → {1, 1}
      assert count == n(1)
      assert total == n(1)
    end

    test "partial fit ratio returns reduced fraction" do
      # 2 hits out of 4
      p = poly([5])
      points = [{n(0), n(5)}, {n(1), n(5)}, {n(2), n(7)}, {n(3), n(9)}]
      {count, total} = Measure.fit_ratio(p, points)
      # 2/4 → 1/2
      assert count == n(1)
      assert total == n(2)
    end
  end

  # ── Measure.irreducible?/1 ───────────────────────────────────────────────────

  describe "irreducible?/1" do
    test "zero polynomial is not irreducible" do
      assert Measure.irreducible?(Poly.zero()) == false
    end

    test "constant polynomial is not irreducible" do
      assert Measure.irreducible?(Poly.one()) == false
    end

    test "every degree-1 polynomial x + a is irreducible" do
      for a <- 0..126 do
        p = poly([a, 1])
        assert Measure.irreducible?(p) == true,
          "Expected x + #{a} to be irreducible"
      end
    end

    test "x^2 is not irreducible (repeated root at 0)" do
      assert Measure.irreducible?(poly([0, 0, 1])) == false
    end

    test "x^2 - 1 is not irreducible (roots at 1 and 126)" do
      assert Measure.irreducible?(poly([126, 0, 1])) == false
    end

    test "x^2 + 1 is irreducible over GF(127) if it has no roots" do
      p = poly([1, 0, 1])
      # Check: if root_count == 0 then irreducible
      rc = Measure.root_count(p)
      expected = Num127.compare(rc, n(0)) == :eq
      assert Measure.irreducible?(p) == expected
    end

    test "degree-4 polynomial returns {:undetermined}" do
      assert Measure.irreducible?(poly([1, 0, 0, 0, 1])) == {:undetermined}
    end
  end

  # ── Parser / Evaluator integration ───────────────────────────────────────────

  describe "REPL integration" do
    defp eval_repl(str) do
      {:ok, ast} = Base127.Parser.parse(str)
      Base127.Evaluator.eval(ast)
    end

    test "degree x returns 1" do
      {:ok, result} = eval_repl("degree x")
      assert result == n(1)
    end

    test "degree x^2 + 1 returns 2" do
      {:ok, result} = eval_repl("degree x^2 + 1")
      assert result == n(2)
    end

    test "roots x returns [0]" do
      {:ok, result} = eval_repl("roots x")
      assert result == [n(0)]
    end

    test "roots x^2 - 1 returns [1, 126]" do
      {:ok, result} = eval_repl("roots x^2 - 1")
      assert n(1) in result
      assert n(126) in result
      assert length(result) == 2
    end

    test "fit x against [(0, 0), (1, 1)] returns {1, 1} — perfect fit" do
      {:ok, result} = eval_repl("fit x against [(0, 0), (1, 1)]")
      {count, total} = result
      assert count == n(1)
      assert total == n(1)
    end

    test "renderer formats degree result as glyph" do
      {:ok, result} = eval_repl("degree x^2 + 1")
      assert Base127.Renderer.render(result) == "2"
    end

    test "renderer formats roots result as bracketed glyph list" do
      {:ok, result} = eval_repl("roots x")
      assert Base127.Renderer.render(result) == "[0]"
    end

    test "renderer formats roots of x^2 - 1 including ▼ for 126" do
      {:ok, result} = eval_repl("roots x^2 - 1")
      rendered = Base127.Renderer.render(result)
      assert String.contains?(rendered, "▼")
      assert String.contains?(rendered, "1")
    end

    test "renderer formats fit_ratio as count/total glyphs" do
      {:ok, result} = eval_repl("fit x against [(0, 0), (1, 1)]")
      assert Base127.Renderer.render(result) == "1/1"
    end
  end
end
