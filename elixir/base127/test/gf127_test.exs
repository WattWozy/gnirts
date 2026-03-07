defmodule GF127Test do
  use ExUnit.Case
  use ExUnitProperties

  @moduletag timeout: 1000

  # Helper generator for GF127 domain
  def gf_val, do: integer(0..126)
  def gf_nonzero_val, do: integer(1..126)

  property "addition ranges within 0..126" do
    check all a <- gf_val(), b <- gf_val() do
      res = GF127.add(a, b)
      assert res >= 0 and res <= 126
    end
  end

  property "addition is commutative" do
    check all a <- gf_val(), b <- gf_val() do
      assert GF127.add(a, b) == GF127.add(b, a)
    end
  end

  property "addition is associative" do
    check all a <- gf_val(), b <- gf_val(), c <- gf_val() do
      assert GF127.add(GF127.add(a, b), c) == GF127.add(a, GF127.add(b, c))
    end
  end

  property "subtraction is the inverse of addition" do
    check all a <- gf_val(), b <- gf_val() do
      sum = GF127.add(a, b)
      assert GF127.sub(sum, b) == a
    end
  end

  property "0 is the additive identity element" do
    check all a <- gf_val() do
      assert GF127.add(a, 0) == a
      assert GF127.add(0, a) == a
    end
  end

  property "multiplication ranges within 0..126" do
    check all a <- gf_val(), b <- gf_val() do
      res = GF127.mul(a, b)
      assert res >= 0 and res <= 126
    end
  end

  property "multiplication is commutative" do
    check all a <- gf_val(), b <- gf_val() do
      assert GF127.mul(a, b) == GF127.mul(b, a)
    end
  end

  property "multiplication is associative" do
    check all a <- gf_val(), b <- gf_val(), c <- gf_val() do
      assert GF127.mul(GF127.mul(a, b), c) == GF127.mul(a, GF127.mul(b, c))
    end
  end

  property "multiplication distributes over addition" do
    check all a <- gf_val(), b <- gf_val(), c <- gf_val() do
      left = GF127.mul(a, GF127.add(b, c))
      right = GF127.add(GF127.mul(a, b), GF127.mul(a, c))
      assert left == right
    end
  end

  property "1 is the multiplicative identity element" do
    check all a <- gf_val() do
      assert GF127.mul(a, 1) == a
      assert GF127.mul(1, a) == a
    end
  end

  property "0 is the absorbing element for multiplication" do
    check all a <- gf_val() do
      assert GF127.mul(a, 0) == 0
      assert GF127.mul(0, a) == 0
    end
  end

  property "multiplication by inverse yields 1 for all non-zero elements" do
    check all a <- gf_nonzero_val() do
      inv_a = GF127.inv(a)
      assert GF127.mul(a, inv_a) == 1
      assert GF127.mul(inv_a, a) == 1
    end
  end
end
