defmodule Base127.PolyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Base127.Poly

  @zero_coeff []
  @one_coeff [1]

  def poly_gen do
    gen all coeffs <- list_of(list_of(integer(0..126), min_length: 0, max_length: 5), min_length: 0, max_length: 5) do
      # Normalize each coefficient to be a single digit for field properties if possible, 
      # or just any Num127.
      # But prompt says "Polynomials live over GF(127)".
      %Poly{coeffs: coeffs |> Enum.map(&Num127.normalize/1)} |> Poly.normalize()
    end
  end

  property "Poly.add(p, Poly.zero) == p" do
    check all p <- poly_gen() do
      assert Poly.add(p, Poly.zero()) == p
    end
  end

  property "Poly.mul(p, Poly.one) == p" do
    check all p <- poly_gen() do
      # Poly.one is 1. Poly.mul(p, 1) = p.
      assert Poly.mul(p, Poly.one()) == p
    end
  end

  property "Poly.mul(p, q) == Poly.mul(q, p)" do
    check all p <- poly_gen(), q <- poly_gen() do
      assert Poly.mul(p, q) == Poly.mul(q, p)
    end
  end

  property "Poly.eval(Poly.add(p, q), x) == Num127.add(Poly.eval(p, x), Poly.eval(q, x)) mod 127" do
    check all p <- poly_gen(), q <- poly_gen(), x_val <- list_of(integer(0..126), max_length: 2) do
      x_norm = Num127.normalize(x_val)
      sum_p_q = Poly.add(p, q)
      
      eval_sum = Poly.eval(sum_p_q, x_norm)
      eval_p = Poly.eval(p, x_norm)
      eval_q = Poly.eval(q, x_norm)
      
      expected = Num127.add(eval_p, eval_q) |> modularize_num127()
      assert eval_sum == expected
    end
  end

  property "Poly.div(Poly.mul(p, q), q) == {p, Poly.zero} for non-zero q" do
    check all p <- poly_gen(), q <- poly_gen() do
      q_norm = Poly.normalize(q)
      if q_norm.coeffs != [] do
        prod = Poly.mul(p, q_norm)
        {quot, rem} = Poly.div(prod, q_norm)
        assert Poly.normalize(quot) == p
        assert Poly.normalize(rem).coeffs == []
      end
    end
  end

  property "Poly.compose(p, identity) == p" do
    check all p <- poly_gen() do
      assert Poly.compose(p, Poly.identity()) == p
    end
  end

  defp modularize_num127(c) do
    {_, r} = Num127.div_rem(c, [0, 1])
    Num127.normalize(r)
  end
end
