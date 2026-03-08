defmodule Base127.Measure do
  @moduledoc """
  Measurability tools for polynomials over GF(127).
  All operations use exclusively GF127, Num127, Poly, and Interpolation primitives.
  """

  alias Base127.Poly

  # ── Helpers ─────────────────────────────────────────────────────────────────

  # The Num127 representations of key constants.
  @zero []    # Num127.zero
  @one  [1]   # Num127.one

  # Reduce a Num127 coefficient to a single GF127 digit (coefficients live in GF(127)).
  defp to_gf_digit(c) do
    {_, r} = Num127.div_rem(c, [0, 1])  # rem mod 127
    case r do
      [] -> 0
      [d] -> d
    end
  end

  # Compare two Num127 values for equality.
  defp num_eq?(a, b), do: Num127.compare(a, b) == :eq

  # ── fit_count ───────────────────────────────────────────────────────────────

  @doc """
  Count how many points {x_i, y_i} satisfy Poly.eval(poly, x_i) == y_i exactly.
  Returns a Num127 value.  Uses Num127.add to increment — no Elixir +.
  """
  def fit_count(poly, points) do
    do_fit_count(poly, points, @zero)
  end

  defp do_fit_count(_poly, [], count), do: count
  defp do_fit_count(poly, [{x, y} | rest], count) do
    evaluated = Poly.eval(poly, x)
    new_count =
      if num_eq?(evaluated, y) do
        Num127.add(count, @one)
      else
        count
      end
    do_fit_count(poly, rest, new_count)
  end

  # ── fit_ratio ───────────────────────────────────────────────────────────────

  @doc """
  Returns the fit as {count, total} using Num127.exact_div — both are Num127 values.
  A perfect fit returns {n, n}.  Does not approximate or convert to float.
  """
  def fit_ratio(poly, points) do
    count = fit_count(poly, points)
    total = list_length_num127(points, @zero)
    Num127.exact_div(count, total)
  end

  # Count elements of a list using Num127.add, no length/1 or Enum.count/1.
  defp list_length_num127([], acc), do: acc
  defp list_length_num127([_ | rest], acc), do: list_length_num127(rest, Num127.add(acc, @one))

  # ── degree ──────────────────────────────────────────────────────────────────

  @doc """
  Return the degree of a %Poly{} as a Num127 value.
  The zero polynomial returns {:undefined}.
  A constant nonzero polynomial returns Num127.zero (i.e. []).
  Position tracking uses Num127.add — no Elixir length/1 or integer indices.
  """
  def degree(%Poly{coeffs: []}), do: {:undefined}
  def degree(%Poly{coeffs: coeffs}) do
    # Walk the list tracking (current_index, last_nonzero_index).
    # index starts at Num127.zero = [].
    {_final_idx, last_nz} = do_degree(coeffs, @zero, nil)
    case last_nz do
      nil -> {:undefined}  # shouldn't happen since we guarded against []
      idx -> idx
    end
  end

  defp do_degree([], idx, last_nz), do: {idx, last_nz}
  defp do_degree([c | rest], idx, last_nz) do
    # Normalise the coefficient to check if it's zero.
    c_norm = Num127.normalize(c)
    new_last_nz =
      if c_norm == @zero do
        last_nz
      else
        idx
      end
    do_degree(rest, Num127.add(idx, @one), new_last_nz)
  end

  # ── roots ───────────────────────────────────────────────────────────────────

  @doc """
  Find all roots of a polynomial in GF(127) by exhaustive evaluation.
  Returns {:error, :zero_poly} for the zero polynomial.
  The iteration over all 127 field elements is driven exclusively by Num127.add —
  no Range, no Enum.to_list(0..126), no Elixir integer iteration.
  """
  def roots(%Poly{coeffs: []}), do: {:error, :zero_poly}
  def roots(poly) do
    # Build candidates 0, 1, ..., 126 and collect roots.
    limit = Num127.from_integer(127)   # sentinel — stop when candidate == limit
    do_roots(poly, @zero, limit, [])
  end

  defp do_roots(_poly, candidate, limit, acc) when candidate == limit do
    Enum.reverse(acc)
  end
  defp do_roots(poly, candidate, limit, acc) do
    # We cannot pattern-match Num127 lists directly in guards with ==
    # across all representations, so use compare.
    if num_eq?(candidate, limit) do
      Enum.reverse(acc)
    else
      ev = Poly.eval(poly, candidate)
      new_acc =
        if num_eq?(ev, @zero) do
          [candidate | acc]
        else
          acc
        end
      do_roots(poly, Num127.add(candidate, @one), limit, new_acc)
    end
  end

  # ── root_count ──────────────────────────────────────────────────────────────

  @doc """
  Return the number of roots as a Num127 value.
  """
  def root_count(poly) do
    case roots(poly) do
      {:error, _} = err -> err
      root_list -> list_length_num127(root_list, @zero)
    end
  end

  # ── irreducible? ─────────────────────────────────────────────────────────────

  @doc """
  A polynomial over GF(127) is irreducible if:
  - degree 1: always true
  - degree 2 or 3: true iff root_count == 0
  - degree 0 or {:undefined}: false
  - degree >= 4: {:undetermined}
  """
  def irreducible?(poly) do
    case degree(poly) do
      {:undefined} ->
        false

      deg ->
        cond do
          num_eq?(deg, @zero) ->
            # Constant nonzero polynomial — not irreducible
            false

          num_eq?(deg, @one) ->
            true

          num_eq?(deg, Num127.from_integer(2)) or num_eq?(deg, Num127.from_integer(3)) ->
            num_eq?(root_count(poly), @zero)

          true ->
            {:undetermined}
        end
    end
  end
end
