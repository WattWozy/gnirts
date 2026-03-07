defmodule Num127 do
  @moduledoc """
  Multi-digit Base-127 number representation.
  Represents positive integers as a little-endian list of digits in 0..126.
  Also represents exact rationals as `{numerator, denominator}`.
  """

  @type t :: [integer()]

  @alphabet_list String.graphemes("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~¡¢£¤¥¦§¨©ª«¬®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂ")
  @val_to_char @alphabet_list |> Enum.with_index(fn char, idx -> {idx, char} end) |> Enum.into(%{})

  @doc "Normalizes a Base-127 number by stripping trailing zeros (leading zeros in Big-Endian)."
  @spec normalize(t()) :: t()
  def normalize(digits) do
    digits
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == 0))
    |> Enum.reverse()
  end

  @doc "Converts a standard Elixir integer to Num127 list."
  def from_integer(0), do: []
  def from_integer(n) when n > 0 do
    [rem(n, 127) | from_integer(div(n, 127))]
  end

  @doc "Converts a Num127 list to standard Elixir integer."
  def to_integer([]), do: 0
  def to_integer([d | rest]), do: d + 127 * to_integer(rest)

  @doc "Addition with carry propagation using GF127."
  def add(a, b) do
    do_add(a, b, 0) |> normalize()
  end

  defp do_add([], [], 0), do: []
  defp do_add([], [], 1), do: [1]
  defp do_add([h | t], [], carry), do: do_add([h | t], [0], carry)
  defp do_add([], [h | t], carry), do: do_add([0], [h | t], carry)
  defp do_add([h1 | t1], [h2 | t2], carry) do
    {sum, carry_out} = add_digits(h1, h2, carry)
    [sum | do_add(t1, t2, carry_out)]
  end

  defp add_digits(a, b, carry_in) do
    sum1 = GF127.add(a, b)
    c1 = if sum1 < a, do: 1, else: 0
    sum2 = GF127.add(sum1, carry_in)
    c2 = if sum2 < sum1, do: 1, else: 0
    {sum2, c1 + c2}
  end

  @doc "Subtraction with borrow propagation, assuming a >= b."
  def sub(a, b) do
    case compare(a, b) do
      :lt -> raise ArgumentError, "subtraction result is negative"
      :eq -> []
      :gt -> do_sub(a, b, 0) |> normalize()
    end
  end

  defp do_sub([], [], 0), do: []
  defp do_sub([h | t], [], borrow), do: do_sub([h | t], [0], borrow)
  defp do_sub([h1 | t1], [h2 | t2], borrow) do
    {diff, borrow_out} = sub_digits(h1, h2, borrow)
    [diff | do_sub(t1, t2, borrow_out)]
  end

  defp sub_digits(a, b, borrow_in) do
    diff1 = GF127.sub(a, b)
    b1 = if a < b, do: 1, else: 0

    diff_final = GF127.sub(diff1, borrow_in)
    b2 = if diff1 < borrow_in, do: 1, else: 0

    {diff_final, b1 + b2}
  end

  @doc "Multiplication using GF127 for lower product and long-multiplication."
  def mul(a, b) do
    # a * b = sum of (a * b_i * 127^i)
    # We multiply a by each digit of b, shifting with leading zeroes.
    b
    |> Enum.with_index()
    |> Enum.reduce([], fn {b_digit, idx}, acc ->
      partial = List.duplicate(0, idx) ++ mul_digit(a, b_digit)
      add(acc, partial)
    end)
    |> normalize()
  end

  def mul_digit(num, single_d) do
    do_mul_digit(num, single_d, 0) |> normalize()
  end

  defp do_mul_digit([], _d, 0), do: []
  defp do_mul_digit([], _d, carry), do: [carry]
  defp do_mul_digit([h | t], d, carry) do
    m_low = GF127.mul(h, d)
    m_high = div(h * d, 127) # non-modular arithmetic to find multiplication carry
    {sum_low, c_out} = add_digits(m_low, carry, 0)
    [sum_low | do_mul_digit(t, d, m_high + c_out)]
  end

  @doc "Compares two Num127, returning :eq, :gt, or :lt."
  def compare(a, b) do
    a_norm = normalize(a)
    b_norm = normalize(b)
    len_a = length(a_norm)
    len_b = length(b_norm)
    cond do
      len_a > len_b -> :gt
      len_a < len_b -> :lt
      true ->
        compare_same_len(Enum.reverse(a_norm), Enum.reverse(b_norm))
    end
  end

  defp compare_same_len([], []), do: :eq
  defp compare_same_len([ha | ta], [hb | tb]) do
    cond do
      ha > hb -> :gt
      ha < hb -> :lt
      true -> compare_same_len(ta, tb)
    end
  end

  @doc "Division with remainder."
  def div_rem(num, den) do
    n = normalize(num)
    d = normalize(den)
    if d == [], do: raise(ArithmeticError, "divide by zero")
    case compare(n, d) do
      :lt -> {[], n}
      :eq -> {[1], []}
      :gt -> do_long_div(Enum.reverse(n), d)
    end
  end

  defp do_long_div(n_rev, d) do
    Enum.reduce(n_rev, {[], []}, fn curr_digit, {q, r} ->
      new_r = [curr_digit | r] |> normalize()
      q_digit = find_q(new_r, d, 0, 126)
      new_r = sub(new_r, mul_digit(d, q_digit))
      {[q_digit | q], new_r}
    end)
    |> fn {q_rev, r} -> {normalize(q_rev), normalize(r)} end.()
  end

  defp find_q(r, d, low, high) do
    if low > high do
      high
    else
      mid = div(low + high, 2)
      product = mul_digit(d, mid)
      case compare(product, r) do
        :eq -> mid
        :lt -> find_q(r, d, mid + 1, high)
        :gt -> find_q(r, d, low, mid - 1)
      end
    end
  end

  @doc "GCD of two Num127s."
  def gcd(a, []), do: normalize(a)
  def gcd(a, b) do
    {_q, r} = div_rem(a, b)
    gcd(b, r)
  end

  @doc "Exact division yielding a lazy rational {numerator, denominator} in lowest terms."
  def exact_div(num, den) do
    n = normalize(num)
    d = normalize(den)
    if d == [], do: raise(ArithmeticError, "divide by zero")
    g = gcd(n, d)
    {q_n, []} = div_rem(n, g)
    {q_d, []} = div_rem(d, g)
    {q_n, q_d}
  end

  @doc "Converts a Num127 string to our Base127 printable glyph alphabet."
  def to_string([]), do: Map.fetch!(@val_to_char, 0)
  def to_string(digits) do
    norm = normalize(digits)
    if norm == [] do
      Map.fetch!(@val_to_char, 0)
    else
      norm
      |> Enum.reverse() # big endian for reading left-to-right
      |> Enum.map(&Map.fetch!(@val_to_char, &1))
      |> Enum.join("")
    end
  end
end
