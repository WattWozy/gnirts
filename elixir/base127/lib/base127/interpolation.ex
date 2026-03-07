defmodule Base127.Interpolation do
  @moduledoc """
  Polynomial interpolation over GF(127).
  """

  alias Base127.Poly
  import Kernel, except: [div: 2]

  @doc """
  Lagrange interpolation over GF(127).
  Input: list of {x_i, y_i} pairs where each x_i, y_i is a Num127 value.
  """
  def lagrange(points) do
    with :ok <- check_distinct_x(points) do
      res = Enum.reduce(points, Poly.zero(), fn {x_i, y_i}, acc ->
        basis = lagrange_basis(points, x_i)
        term = Poly.scale(basis, y_i)
        Poly.add(acc, term)
      end)
      Poly.normalize(res)
    end
  end

  defp lagrange_basis(points, x_i) do
    # L_i(x) = ∏_{j ≠ i} (x - x_j) / (x_i - x_j)
    Enum.reduce(points, Poly.one(), fn {x_j, _}, acc ->
      if Num127.compare(x_i, x_j) == :eq do
        acc
      else
        # Numerator: (x - x_j)
        # Denominator: (x_i - x_j)
        num = Poly.sub(Poly.identity(), %Poly{coeffs: [x_j]})
        
        # denom = x_i - x_j in GF127
        # We need to compute (x_i - x_j) mod 127
        denom_num = sub_num127_mod(x_i, x_j)
        
        # d_val = case denom_num do [] -> 0; [d] -> d end
        # inv_d = [GF127.inv(d_val)] |> Num127.normalize()
        inv_d = inverse_num127(denom_num)
        
        Poly.mul(acc, Poly.scale(num, inv_d))
      end
    end)
  end

  @doc """
  Newton's divided difference interpolation over GF(127).
  """
  def newton(points) do
    with :ok <- check_distinct_x(points) do
      x_vals = Enum.map(points, &elem(&1, 0))
      y_vals = Enum.map(points, &elem(&1, 1))
      
      coefs = divided_differences(x_vals, y_vals)
      
      # p(x) = c0 + c1(x-x0) + c2(x-x0)(x-x1) + ...
      {final_poly, _} = Enum.reduce(coefs, {Poly.zero(), Poly.one()}, fn c_i, {poly_acc, basis_acc} ->
        term = Poly.scale(basis_acc, c_i)
        new_poly = Poly.add(poly_acc, term)
        
        # Update basis_acc: basis_acc * (x - x_i)
        # Wait, we need the corresponding x_i.
        {new_poly, basis_acc} # Placeholder, recursion below is better
      end)

      # Recursive construction is cleaner
      construct_newton(coefs, x_vals, Poly.zero(), Poly.one())
    end
  end

  defp construct_newton([], _x_vals, poly, _basis), do: Poly.normalize(poly)
  defp construct_newton([c | c_rest], [x | x_rest], poly, basis) do
    term = Poly.scale(basis, c)
    new_poly = Poly.add(poly, term)
    
    # new_basis = basis * (x_indet - x_point)
    factor = Poly.sub(Poly.identity(), %Poly{coeffs: [x]})
    new_basis = Poly.mul(basis, factor)
    
    construct_newton(c_rest, x_rest, new_poly, new_basis)
  end

  defp divided_differences(x_vals, y_vals) do
    # Table of divided differences
    # First column is y_vals
    do_divided_differences([y_vals], x_vals)
  end

  defp do_divided_differences(table, x_vals) do
    prev_col = List.last(table)
    if length(prev_col) == 1 do
      Enum.map(table, &List.first/1)
    else
      new_col = compute_next_col(prev_col, x_vals, length(table))
      do_divided_differences(table ++ [new_col], x_vals)
    end
  end

  defp compute_next_col(prev_col, x_vals, k) do
    # f[x_i, ..., x_{i+k}] = (f[x_{i+1}, ..., x_{i+k}] - f[x_i, ..., x_{i+k-1}]) / (x_{i+k} - x_i)
    # prev_col contains f[x_j, ..., x_{j+k-1}]
    # We want new_col[i] = (prev_col[i+1] - prev_col[i]) / (x_{i+k} - x_i)
    
    Enum.reduce(0..(length(prev_col) - 2), [], fn i, acc ->
      num = sub_num127_mod(Enum.at(prev_col, i + 1), Enum.at(prev_col, i))
      den = sub_num127_mod(Enum.at(x_vals, i + k), Enum.at(x_vals, i))
      
      # res = num / den in GF127
      res = mul_num127_mod(num, inverse_num127(den))
      acc ++ [res]
    end)
  end

  @doc """
  Barycentric Lagrange interpolation.
  """
  def evaluate_at(points, x) do
    with :ok <- check_distinct_x(points) do
      # Fixed form: P(x) = (∑ y_i * w_i / (x - x_i)) / (∑ w_i / (x - x_i))
      # w_i = ∏_{j ≠ i} 1 / (x_i - x_j)
      
      # Check if x is one of the x_i
      case Enum.find(points, fn {x_p, _} -> Num127.compare(x, x_p) == :eq end) do
        {_, y_p} -> y_p
        nil ->
          weights = compute_barycentric_weights(points)
          
          {num, den} = Enum.reduce(Enum.zip(points, weights), {[], []}, fn {{x_i, y_i}, w_i}, {n_acc, d_acc} ->
            # term = w_i / (x - x_i)
            diff = sub_num127_mod(x, x_i)
            term = mul_num127_mod(w_i, inverse_num127(diff))
            
            new_n = add_num127_mod(n_acc, mul_num127_mod(y_i, term))
            new_d = add_num127_mod(d_acc, term)
            {new_n, new_d}
          end)
          
          mul_num127_mod(num, inverse_num127(den))
      end
    end
  end

  defp compute_barycentric_weights(points) do
    x_vals = Enum.map(points, &elem(&1, 0))
    Enum.map(x_vals, fn x_i ->
      prod = Enum.reduce(x_vals, [1], fn x_j, acc ->
        if Num127.compare(x_i, x_j) == :eq do
          acc
        else
          diff = sub_num127_mod(x_i, x_j)
          mul_num127_mod(acc, diff)
        end
      end)
      inverse_num127(prod)
    end)
  end

  @doc """
  Samples a polynomial at n points and recovers it.
  """
  def recover_poly(poly, n_points) do
    # n_points is a Num127
    if Num127.compare(n_points, Num127.from_integer(127)) == :gt do
      {:error, :insufficient_field_elements}
    else
      # Sample at 0, 1, 2, ..., n_points-1
      points = sample_poly(poly, n_points)
      lagrange(points)
    end
  end

  defp sample_poly(poly, n_points) do
    # Generate n_points distinct x values from GF127
    limit = Num127.to_integer(n_points)
    for i <- 0..(limit - 1) do
      x = Num127.from_integer(i)
      {x, Poly.eval(poly, x)}
    end
  end

  # --- Helpers ---

  defp check_distinct_x(points) do
    x_vals = Enum.map(points, &elem(&1, 0))
    if length(Enum.uniq(x_vals)) == length(x_vals) do
      :ok
    else
      {:error, :duplicate_x}
    end
  end

  defp sub_num127_mod(a, b) do
    # (a - b) mod 127
    {_, r_a} = Num127.div_rem(a, [0, 1])
    {_, r_b} = Num127.div_rem(b, [0, 1])
    d_a = case r_a do [] -> 0; [d] -> d end
    d_b = case r_b do [] -> 0; [d] -> d end
    [GF127.sub(d_a, d_b)] |> Num127.normalize()
  end

  defp add_num127_mod(a, b) do
    # (a + b) mod 127
    {_, r_a} = Num127.div_rem(a, [0, 1])
    {_, r_b} = Num127.div_rem(b, [0, 1])
    d_a = case r_a do [] -> 0; [d] -> d end
    d_b = case r_b do [] -> 0; [d] -> d end
    [GF127.add(d_a, d_b)] |> Num127.normalize()
  end

  defp mul_num127_mod(a, b) do
    # (a * b) mod 127
    {_, r_a} = Num127.div_rem(a, [0, 1])
    {_, r_b} = Num127.div_rem(b, [0, 1])
    d_a = case r_a do [] -> 0; [d] -> d end
    d_b = case r_b do [] -> 0; [d] -> d end
    [GF127.mul(d_a, d_b)] |> Num127.normalize()
  end

  defp inverse_num127(a) do
    {_, r} = Num127.div_rem(a, [0, 1])
    d = case r do [] -> raise "Division by zero in GF127"; [val] -> val end
    [GF127.inv(d)] |> Num127.normalize()
  end
end
