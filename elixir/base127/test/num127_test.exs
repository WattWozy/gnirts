defmodule Num127Test do
  use ExUnit.Case
  use ExUnitProperties

  @moduletag timeout: 2000

  # Helper to generate large integers
  def large_int do
    # Generates a large integer up to huge values (e.g. 10..10_000_000)
    integer(0..1_000_000_000)
  end

  property "round-trip conversion to and from integer" do
    check all n <- large_int() do
      assert Num127.from_integer(n) |> Num127.to_integer() == n
    end
  end

  property "addition exactly matches Elixir integer addition" do
    check all a <- large_int(), b <- large_int() do
      num_a = Num127.from_integer(a)
      num_b = Num127.from_integer(b)

      assert Num127.add(num_a, num_b) |> Num127.to_integer() == a + b
    end
  end

  property "subtraction exactly matches Elixir integer subtraction when a >= b" do
    check all a <- large_int(), b <- large_int() do
      # Ensure a >= b
      {max_val, min_val} = if a > b, do: {a, b}, else: {b, a}

      num_max = Num127.from_integer(max_val)
      num_min = Num127.from_integer(min_val)

      assert Num127.sub(num_max, num_min) |> Num127.to_integer() == max_val - min_val
    end
  end

  property "multiplication exactly matches Elixir integer multiplication" do
    check all a <- integer(0..100_000), b <- integer(0..100_000) do
      num_a = Num127.from_integer(a)
      num_b = Num127.from_integer(b)

      assert Num127.mul(num_a, num_b) |> Num127.to_integer() == a * b
    end
  end

  test "subtraction throws when negative" do
    assert_raise ArgumentError, "subtraction result is negative", fn ->
      Num127.sub(Num127.from_integer(5), Num127.from_integer(10))
    end
  end

  property "div_rem exactly matches Elixir division and remainder" do
    check all a <- integer(0..200_000), b <- integer(1..1000) do
      num_a = Num127.from_integer(a)
      num_b = Num127.from_integer(b)
      
      {q, r} = Num127.div_rem(num_a, num_b)
      assert Num127.to_integer(q) == div(a, b)
      assert Num127.to_integer(r) == rem(a, b)
    end
  end

  property "exact division reduces GCD and behaves as correct rational" do
    check all a <- integer(0..5_000), b <- integer(1..5_000) do
      g = Integer.gcd(a, b)
      exp_n = div(a, g)
      exp_d = div(b, g)

      {num_n, num_d} = Num127.exact_div(Num127.from_integer(a), Num127.from_integer(b))

      assert Num127.to_integer(num_n) == exp_n
      assert Num127.to_integer(num_d) == exp_d
    end
  end

  test "to_string representation" do
    # Just a sanity check that to_string works on 0
    assert Num127.to_string([]) == "0"
    assert Num127.to_string([0]) == "0"
    
    # Check alphabet boundary
    assert Num127.to_string([1]) == "1"
    assert Num127.to_string([126]) == "Â"
  end

  property "pow(a, 3) matches mul(mul(a, a), a)" do
    check all a <- integer(0..10_000) do
      num_a = Num127.from_integer(a)
      res_pow = Num127.pow(num_a, [3])
      res_mul = Num127.mul(Num127.mul(num_a, num_a), num_a)
      assert res_pow == res_mul
    end
  end
end
