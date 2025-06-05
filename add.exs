defmodule FunAdd do
  @symbols [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j, :k, :l, :m, :n, :o, :p, :q, :r, :s, :t, :u, :v, :w, :x, :y, :z, :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K, :L, :M, :N, :O, :P, :Q, :R, :S, :T, :U, :V, :W, :X, :Y, :Z]
  @length length(@symbols)

  @symbol_to_val Enum.with_index(@symbols, 0) |> Enum.into(%{})

  def add(:zero, b), do: b
  def add(a, :zero), do: a

  def add(a, b) when is_atom(a) and is_atom(b) do
    a_steps = Map.get(@symbol_to_val, a, 0)
    IO.puts("a_steps: #{a_steps}")
    b_index = Map.get(@symbol_to_val, b, 0)
    IO.puts("b_index: #{b_index}")
    final_sum = 145#a_steps + b_index
    IO.puts("final_sum: #{final_sum}")

    if final_sum <= @length do
      Enum.at(@symbols, final_sum)
    else
      path = encode_base_symbolic(div(final_sum, @length))

      stop = Enum.at(@symbols, rem(final_sum, @length))
      {path, stop}
    end
  end

  defp encode_base_symbolic(0), do: [:a]
  defp encode_base_symbolic(n), do: do_encode(n, [])

  defp do_encode(0, acc), do: acc
  defp do_encode(n, acc) do
    r = rem(n, @length)
    sym = Enum.at(@symbols, r)
    do_encode(div(n, @length), [sym | acc])
  end     # {:a, :b}

end

IO.inspect(FunAdd.add(:b, :c))      # :c
IO.inspect(FunAdd.add(:f, :zero))   # :a
IO.inspect(FunAdd.add(:f, :g))      # {:a, :b}
