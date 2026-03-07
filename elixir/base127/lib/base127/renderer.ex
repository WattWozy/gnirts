defmodule Base127.Renderer do
  @moduledoc """
  Renders Base-127 values as strings.
  Values can be %Num127{} (integers), {:num_neg, digits}, or {:rat, n, d, sign}.
  """

  alias Base127.Alphabet

  @doc "Renders a value to its canonical Base-127 string representation."
  def render(val) do
    case val do
      [] -> Alphabet.encode(0)
      digits when is_list(digits) -> render_unsigned(digits)
      {:num_neg, digits} -> "-" <> render_unsigned(digits)
      {:rat, n, d, sign} ->
        prefix = if sign == :neg, do: "-", else: ""
        prefix <> render_unsigned(n) <> "/" <> render_unsigned(d)
    end
  end

  defp render_unsigned(digits) do
    digits
    |> Num127.normalize()
    |> case do
      [] -> Alphabet.encode(0)
      norm ->
        norm
        |> Enum.reverse() # big-endian
        |> Enum.map(&Alphabet.encode/1)
        |> Enum.join("")
    end
  end

  @doc "Renders a base-127 decimal approximation to N fractional digits."
  def approx(val, precision) do
    {n, d, sign} = to_rational(val)
    prefix = if sign == :neg, do: "-", else: ""
    
    # Integer part
    {q, r} = Num127.div_rem(n, d)
    int_str = render_unsigned(q)
    
    if precision <= 0 or r == [] do
      prefix <> int_str
    else
      # Fractional part via long division
      frac_digits = long_div_frac(r, d, precision)
      frac_str = frac_digits |> Enum.map(&Alphabet.encode/1) |> Enum.join("")
      prefix <> int_str <> "." <> frac_str
    end
  end

  defp long_div_frac(_r, _d, 0), do: []
  defp long_div_frac([], _d, _p), do: []
  defp long_div_frac(r, d, p) do
    # next_r = r * 127
    next_r = Num127.mul(r, [0, 1])
    {q_digit_list, rem_r} = Num127.div_rem(next_r, d)
    q_digit = case q_digit_list do
      [] -> 0
      [d] -> d
      # Should not happen if r < d?
      _ -> Num127.to_integer(q_digit_list)
    end
    [q_digit | long_div_frac(rem_r, d, p - 1)]
  end

  defp to_rational(digits) when is_list(digits), do: {digits, [1], :pos}
  defp to_rational({:num_neg, digits}), do: {digits, [1], :neg}
  defp to_rational({:rat, n, d, sign}), do: {n, d, sign}
end
