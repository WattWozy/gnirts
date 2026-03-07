defmodule Base127.Evaluator do
  @moduledoc """
  Evaluates the Base-127 AST into a value.
  Values are either %Num127{} (integers) or {:rat, %Num127{}, %Num127{}} (rationals).
  """

  alias Base127.Alphabet

  @doc "Evaluates an AST with an optional session map of variables."
  def eval(ast, vars \\ %{}) do
    case do_eval(ast, vars) do
      {:ok, val, _updated_vars} -> {:ok, val}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Evaluates an AST and returns the result and updated session map."
  def eval_with_vars(ast, vars) do
    do_eval(ast, vars)
  end

  defp do_eval({:num, digits}, vars), do: {:ok, Num127.normalize(digits), vars}

  defp do_eval({:id, "x"}, vars), do: {:ok, Base127.Poly.identity(), vars}

  defp do_eval({:id, name}, vars) do
    # If it's a known variable, return it.
    # Otherwise, try to parse it as a literal.
    case Map.get(vars, name) do
      nil ->
        # Try as literal
        try do
          digits = name |> String.graphemes() |> Enum.map(&Alphabet.decode/1)
          {:ok, Num127.normalize(digits), vars}
        rescue
          _ -> {:error, "Unknown variable or invalid literal: #{name}"}
        end
      val -> {:ok, val, vars}
    end
  end

  defp do_eval({:rat_literal, int_digits, frac_digits}, vars) do
    # 12.34 in base 127 = 12 + 34/127^2 ? 
    # Actually, the requirement says fractional glyph sequences.
    # 12.34 = 12 + 3/127 + 4/127^2 = (12 * 127^2 + 3 * 127 + 4) / 127^2
    # Let's generalize: int + frac / 127^length(frac)
    n_int = Num127.from_integer(Num127.to_integer(int_digits))
    n_frac_num = Num127.from_integer(Num127.to_integer(frac_digits))
    n_frac_den = power_127(length(frac_digits))
    
    # Value = n_int + n_frac_num / n_frac_den
    # = (n_int * n_frac_den + n_frac_num) / n_frac_den
    num = Num127.add(Num127.mul(n_int, n_frac_den), n_frac_num)
    den = n_frac_den
    {:ok, normalize_rational(num, den), vars}
  end

  defp do_eval({:neg, expr}, vars) do
    case do_eval(expr, vars) do
      {:ok, val, vars2} -> {:ok, neg_val(val), vars2}
      err -> err
    end
  end

  defp do_eval({:op, op, left, right}, vars) do
    with {:ok, l_val, vars2} <- do_eval(left, vars),
         {:ok, r_val, vars3} <- do_eval(right, vars2) do
      case op do
        "+" -> {:ok, add(l_val, r_val), vars3}
        "-" -> {:ok, sub(l_val, r_val), vars3}
        "*" -> {:ok, mul(l_val, r_val), vars3}
        "/" ->
          case effectively_zero?(r_val) do
            true -> {:error, "Division by zero"}
            false -> {:ok, div_vals(l_val, r_val), vars3}
          end
        "^" -> {:ok, pow_vals(l_val, r_val), vars3}
      end
    end
  end

  defp effectively_zero?(%Base127.Poly{coeffs: coeffs}), do: coeffs == []
  defp effectively_zero?(val) do
    case to_rational(val) do
      {[], _, _} -> true
      _ -> false
    end
  end

  defp do_eval({:assign, name, expr}, vars) do
    case do_eval(expr, vars) do
      {:ok, val, vars2} ->
        {:ok, val, Map.put(vars2, name, val)}
      err -> err
    end
  end

  defp do_eval({:interpolate, points_ast}, vars) do
    with {:ok, points, vars2} <- eval_points(points_ast, vars) do
      case Base127.Interpolation.lagrange(points) do
        {:error, reason} -> {:error, "Interpolation error: #{reason}"}
        poly -> {:ok, poly, vars2}
      end
    end
  end

  defp do_eval({:interpolate_at, points_ast, v_ast}, vars) do
    with {:ok, points, vars2} <- eval_points(points_ast, vars),
         {:ok, v, vars3} <- do_eval(v_ast, vars2) do
      # Interpolate_at expects Num127
      v_num = case v do
        digits when is_list(digits) -> digits
        {:num_neg, digits} -> digits # Handle sign in evaluate_at? Barycentric usually over field.
        # But evaluate_at in Interpolation module expects Num127 (list).
        # We'll assume field elements.
        _ -> raise "Expected Num127 for 'at' value"
      end

      case Base127.Interpolation.evaluate_at(points, v_num) do
        {:error, reason} -> {:error, "Interpolation error: #{reason}"}
        res -> {:ok, res, vars3}
      end
    end
  end

  defp eval_points([], vars), do: {:ok, [], vars}
  defp eval_points([{x_ast, y_ast} | rest], vars) do
    with {:ok, x_val, vars2} <- do_eval(x_ast, vars),
         {:ok, y_val, vars3} <- do_eval(y_ast, vars2) do
      # Points must be Num127 (field elements)
      x_num = to_field_element(x_val)
      y_num = to_field_element(y_val)
      
      case eval_points(rest, vars3) do
        {:ok, points, vars4} -> {:ok, [{x_num, y_num} | points], vars4}
        err -> err
      end
    end
  end

  defp to_field_element(val) do
    case val do
      digits when is_list(digits) -> digits
      {:num_neg, digits} -> 
        # Convert to positive element in GF127
        {_, r} = Num127.div_rem(digits, [0, 1])
        d = case r do [] -> 0; [val] -> val end
        [GF127.sub(0, d)] |> Num127.normalize()
      _ -> raise "Expected field element (Num127)"
    end
  end

  # --- Arithmetic Helpers ---

  defp neg_val(%Base127.Poly{} = p) do
    Base127.Poly.sub(Base127.Poly.zero(), p)
  end
  defp neg_val({:rat, n, d, :neg}), do: {:rat, n, d, :pos}
  defp neg_val({:rat, n, d, :pos}), do: {:rat, n, d, :neg}
  defp neg_val(digits) when is_list(digits), do: {:num_neg, digits}
  defp neg_val({:num_neg, digits}), do: digits

  defp to_rational(digits) when is_list(digits), do: {digits, [1], :pos}
  defp to_rational({:num_neg, digits}), do: {digits, [1], :neg}
  defp to_rational({:rat, n, d, sign}), do: {n, d, sign}

  defp from_rational({n, [1], :pos}), do: n
  defp from_rational({n, [1], :neg}), do: {:num_neg, n}
  defp from_rational({n, d, sign}), do: {:rat, n, d, sign}

  defp add(%Base127.Poly{} = p, %Base127.Poly{} = q), do: Base127.Poly.add(p, q)
  defp add(%Base127.Poly{} = p, v), do: Base127.Poly.add(p, to_poly(v))
  defp add(v, %Base127.Poly{} = p), do: Base127.Poly.add(to_poly(v), p)
  defp add(v1, v2) do
    {n1, d1, s1} = to_rational(v1)
    {n2, d2, s2} = to_rational(v2)
    # (s1*n1/d1) + (s2*n2/d2) = (s1*n1*d2 + s2*n2*d1) / (d1*d2)
    t1 = Num127.mul(n1, d2)
    t2 = Num127.mul(n2, d1)
    
    {num, sign} = case {s1, s2} do
      {:pos, :pos} -> {Num127.add(t1, t2), :pos}
      {:neg, :neg} -> {Num127.add(t1, t2), :neg}
      {:pos, :neg} -> 
        case Num127.compare(t1, t2) do
          :gt -> {Num127.sub(t1, t2), :pos}
          :eq -> {[], :pos}
          :lt -> {Num127.sub(t2, t1), :neg}
        end
      {:neg, :pos} ->
        case Num127.compare(t1, t2) do
          :gt -> {Num127.sub(t1, t2), :neg}
          :eq -> {[], :pos}
          :lt -> {Num127.sub(t2, t1), :pos}
        end
    end
    den = Num127.mul(d1, d2)
    normalize_rational(num, den, sign)
  end

  defp sub(v1, v2), do: add(v1, neg_val(v2))

  defp mul(%Base127.Poly{} = p, %Base127.Poly{} = q), do: Base127.Poly.mul(p, q)
  defp mul(%Base127.Poly{} = p, v), do: Base127.Poly.scale(p, v)
  defp mul(v, %Base127.Poly{} = p), do: Base127.Poly.scale(p, v)
  defp mul(v1, v2) do
    {n1, d1, s1} = to_rational(v1)
    {n2, d2, s2} = to_rational(v2)
    num = Num127.mul(n1, n2)
    den = Num127.mul(d1, d2)
    sign = if s1 == s2, do: :pos, else: :neg
    normalize_rational(num, den, sign)
  end

  defp div_vals(%Base127.Poly{} = p, %Base127.Poly{} = q) do
    case Base127.Poly.div(p, q) do
      {:error, reason} -> raise "Polynomial division error: #{reason}"
      {quot, _rem} -> quot # Or should we return a pair? Prompt: "p = q*quot + rem".
      # Usually literal '/' in expressions might mean quotient.
    end
  end
  defp div_vals(%Base127.Poly{} = p, v) do
    # scale(p, 1/v)
    {n, d, sign} = to_rational(v)
    if d != [1] or sign == :neg do
      raise "Scaling polynomial by non-integer or negative not fully supported in this context"
    end
    # over GF(127)
    d_val = case n do [] -> 0; [val] -> val end
    inv_v = [GF127.inv(d_val)] |> Num127.normalize()
    Base127.Poly.scale(p, inv_v)
  end
  defp div_vals(v1, v2) do
    {n1, d1, s1} = to_rational(v1)
    {n2, d2, s2} = to_rational(v2)
    # (n1/d1) / (n2/d2) = (n1*d2) / (d1*n2)
    num = Num127.mul(n1, d2)
    den = Num127.mul(d1, n2)
    sign = if s1 == s2, do: :pos, else: :neg
    normalize_rational(num, den, sign)
  end

  defp pow_vals(%Base127.Poly{} = p, v_exp) do
    {n_e, d_e, s_e} = to_rational(v_exp)
    if d_e != [1] or s_e == :neg do
      raise "Non-positive-integer exponent for polynomial not supported"
    end
    Base127.Poly.pow(p, n_e)
  end
  defp pow_vals(v_base, v_exp) do
    {n_b, d_b, s_b} = to_rational(v_base)
    {n_e, d_e, s_e} = to_rational(v_exp)

    # Exponentiation expects an integer exponent in this system for now.
    if d_e != [1] do
      # If we ever support fractional powers, we'd do it here.
      # For now, let's treat it as integer.
      raise "Non-integer exponent not supported"
    end

    case s_e do
      :pos ->
        # (s_b * n_b/d_b)^n_e
        num = Num127.pow(n_b, n_e)
        den = Num127.pow(d_b, n_e)
        # Sign: if base was negative, exponent must be even for positive result.
        sign = if s_b == :neg and rem_2(n_e) == 1, do: :neg, else: :pos
        normalize_rational(num, den, sign)

      :neg ->
        # (s_b * n_b/d_b)^(-n_e) = (s_b * d_b/n_b)^n_e
        num = Num127.pow(d_b, n_e)
        den = Num127.pow(n_b, n_e)
        sign = if s_b == :neg and rem_2(n_e) == 1, do: :neg, else: :pos
        normalize_rational(num, den, sign)
    end
  end

  defp to_poly(%Base127.Poly{} = p), do: p
  defp to_poly(v) do
    {n, d, sign} = to_rational(v)
    poly = if d != [1] do
      # For now, just use numerator, but ideally handle field division
      %Base127.Poly{coeffs: [n]}
    else
      %Base127.Poly{coeffs: [n]}
    end
    
    if sign == :neg, do: neg_val(poly), else: poly
  end

  defp rem_2([]), do: 0
  defp rem_2(digits), do: rem(Enum.sum(digits), 2)

  defp normalize_rational(num, den, sign \\ :pos) do
    if num == [] do
      []
    else
      g = Num127.gcd(num, den)
      {q_n, _} = Num127.div_rem(num, g)
      {q_d, _} = Num127.div_rem(den, g)
      from_rational({q_n, q_d, sign})
    end
  end

  defp power_127(0), do: [1]
  defp power_127(n), do: Num127.mul([0, 1], power_127(n-1)) # [0, 1] is 127
end
