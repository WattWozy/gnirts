defmodule FunAdd do
  @symbols [:ze, :a, :b, :c, :d, :e, :f, :g, :h, :i, :j, :k, :l, :m, :n, :o,
            :p, :q, :r, :s, :t, :u, :v, :w, :x, :y, :z,
            :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K, :L, :M, :N, :O, :P,
            :Q, :R, :S, :T, :U, :V, :W, :X, :Y, :Z]

  @length length(@symbols)
  @symbol_to_val Enum.with_index(@symbols) |> Enum.into(%{})
  @val_to_symbol Enum.with_index(@symbols) |> Enum.into(%{}, fn {s, i} -> {i, s} end)

  # Core addition of single "digits"
  def add(a, b) when is_atom(a) and is_atom(b) do
    a_val = Map.fetch!(@symbol_to_val, a)
    b_val = Map.fetch!(@symbol_to_val, b)
    sum = a_val + b_val

    encode(sum)
  end

  # Convert integer value into symbolic base digits
  defp encode(0), do: [:ze]
  defp encode(n), do: do_encode(n, [])

  defp do_encode(0, acc), do: acc
  defp do_encode(n, acc) do
    r = rem(n, @length)
    sym = Map.fetch!(@val_to_symbol, r)
    do_encode(div(n, @length), [sym | acc])
  end
end

# Tests
IO.inspect(FunAdd.add(:a, :b))     # [:c]   (1+2=3)
IO.inspect(FunAdd.add(:f, :ze))    # [:f]   (5+0=5)
IO.inspect(FunAdd.add(:f, :g))     # [:m]   (6+7=13)
IO.inspect(FunAdd.add(:Z, :Z))     # [:a, :Y]  (carry case)
