defmodule GF127.Builder do
  @moduledoc false
  def eea(a, 0), do: {a, 1, 0}
  def eea(a, b) do
    {g, x1, y1} = eea(b, rem(a, b))
    {g, y1, x1 - div(a, b) * y1}
  end

  def compute_inverse(a) do
    {1, x, _y} = eea(a, 127)
    rem(x + 127, 127)
  end
end

defmodule GF127 do
  @moduledoc """
  Single-digit Base-127 operations utilizing O(1) lookup tables.
  GF(127) arithmetic over integers {0..126}.
  """

  @add_tuple (
    for a <- 0..126 do
      for b <- 0..126 do
        rem(a + b, 127)
      end |> List.to_tuple()
    end |> List.to_tuple()
  )

  @mul_tuple (
    for a <- 0..126 do
      for b <- 0..126 do
        rem(a * b, 127)
      end |> List.to_tuple()
    end |> List.to_tuple()
  )

  @inv_tuple (
    for a <- 0..126 do
      if a == 0 do
        0 # 0 has no multiplicative inverse
      else
        GF127.Builder.compute_inverse(a)
      end
    end |> List.to_tuple()
  )

  @exp_list (
    Stream.iterate(1, fn x -> rem(x * 3, 127) end)
    |> Enum.take(126)
  )

  @exp_tuple List.to_tuple(@exp_list)

  @log_tuple (
    @exp_list
    |> Enum.with_index()
    |> Enum.sort_by(fn {val, _idx} -> val end)
    |> Enum.map(fn {_val, idx} -> idx end)
    |> then(fn list -> [nil | list] end) # 0 has no logarithm
    |> List.to_tuple()
  )

  @doc """
  Addition modulo 127.
  """
  def add(a, b) when a in 0..126 and b in 0..126 do
    elem(elem(@add_tuple, a), b)
  end

  @doc """
  Subtraction modulo 127.
  """
  def sub(a, b) when a in 0..126 and b in 0..126 do
    neg_b = if b == 0, do: 0, else: 127 - b
    add(a, neg_b)
  end

  @doc """
  Multiplication modulo 127.
  """
  def mul(a, b) when a in 0..126 and b in 0..126 do
    elem(elem(@mul_tuple, a), b)
  end

  @doc """
  Multiplicative inverse modulo 127.
  """
  def inv(a) when a in 1..126 do
    elem(@inv_tuple, a)
  end

  @doc """
  Exponentiation modulo 127 using lookup tables.
  GF127.pow(a, n) = EXP[(LOG[a] * rem(n, 126)) mod 126].
  Handle a = 0 separately: 0^n = 0 for n > 0, 0^0 = 1.
  """
  def pow(0, 0), do: 1
  def pow(0, n) when n > 0, do: 0
  def pow(a, n) when a in 1..126 and n >= 0 do
    log_a = elem(@log_tuple, a)
    idx = rem(log_a * rem(n, 126), 126)
    elem(@exp_tuple, idx)
  end
end
