defmodule Base127.Parser do
  @moduledoc """
  Parser for the Base-127 language.
  Converts strings into an AST:
  - {:num, digits}
  - {:rat, numerator, denominator}
  - {:op, operator, left, right}
  - {:neg, expr}
  - {:var, name}
  """

  alias Base127.Alphabet

  @doc "Parses a string into an AST."
  def parse(str) when is_binary(str) do
    tokens = tokenize(str)
    case parse_expression(tokens) do
      {:ok, ast, []} -> {:ok, ast}
      {:ok, _ast, [t | _]} -> {:error, "Unexpected token: #{inspect(t)}"}
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Tokenizer ---

  defp tokenize(""), do: []
  defp tokenize(str) do
    str = String.trim_leading(str)
    cond do
      str == "" -> []
      String.starts_with?(str, "(") -> ["(" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, ")") -> [")" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "+") -> ["+" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "-") -> ["-" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "*") -> ["*" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "/") -> ["/" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "^") -> ["^" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, ".") -> ["." | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "=") -> ["=" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "[") -> ["[" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, "]") -> ["]" | tokenize(String.slice(str, 1..-1//1))]
      String.starts_with?(str, ",") -> ["," | tokenize(String.slice(str, 1..-1//1))]
      # Measure keywords — must be checked before the general identifier splitter.
      String.starts_with?(str, "against") -> ["against" | tokenize(String.slice(str, 7..-1//1))]
      String.starts_with?(str, "degree")  -> ["degree"  | tokenize(String.slice(str, 6..-1//1))]
      String.starts_with?(str, "roots")   -> ["roots"   | tokenize(String.slice(str, 5..-1//1))]
      String.starts_with?(str, "fit")     -> ["fit"     | tokenize(String.slice(str, 3..-1//1))]
      true ->
        # Check for glyphs or variable names (variable names must not start with glyphs if ambiguous)
        # Actually, let's keep it simple: variable names are alphabetic but not single glyphs if they are in Alphabet.
        # But wait, 'a' is a glyph. Let's say variables start with '$' or are just handled after literals.
        # Requirements: "x = 3A + 7". So x is a variable.
        # The alphabet includes A-Z and a-z.
        # Let's assume a "word" is a literal if all characters are in Alphabet.
        # Wait, if 'x' is in the alphabet, it's a digit 0..126.
        # "x = ..." implies 'x' is a variable name.
        # If the user types 'A', is it digit 10 or variable A?
        # Standard: literal digits are the primary interpretation.
        # To support variables like 'x', maybe we should restrict variables to things NOT in alphabet?
        # But a-z is in Alphabet.
        # Let's use a simple rule: if it looks like a literal (glyphs), it's a literal.
        # If it's a sequence of characters starting with something NOT a digit/glyph?
        # Actually, the user says "x = 3A + 7". '3' and 'A' are glyphs. 'x' is a glyph!
        # This is ambiguous. Let's look at the prompt again: "the REPL should support assignment: x = 3A + 7".
        # If 'x' is a glyph (value 59), then "59 = 3*127 + 10 + 7" doesn't make sense as an assignment to a variable.
        # Let's assume variable names are NOT restricted by the alphabet if they are used as identifiers.
        # Or better: any single glyph is a digit. Multiple characters could be a number.
        # But "3A" is a two-digit number.
        # Let's say variables must be at least one char, and if they collide with alphabet, they are digits UNLESS they are on the LHS of '=' or we are in a context.
        # Wait, if 'x' is a digit, "x = ..." is "61 = ...".
        # Let's differentiate: literals are sequences of glyphs. Variables start with an underscore or are specifically handled.
        # Actually, let's just use regex for variable names: [A-Za-z][A-Za-z0-0]* but exclude single-char if it's a digit?
        # No, the alphabet is the source of truth.
        # Let's treat any contiguous sequence of Alphabet characters as a literal first.
        # If it's used in an expression: is it a variable or a number?
        # "3A" is a number. "x" is ?
        # Let's assume everything in Alphabet is a digit.
        # If someone writes "count = 10", and 'c', 'o', 'u', 'n', 't' are all in Alphabet...
        # Then "count" is a base-127 number.
        # This seems intended for this specific "Base-127" language.
        # UNLESS variables are prefixed. But the prompt says "x = ...".
        # Let's assume variables are sequences that might contain Alphabet chars, but we prioritize literals.
        # Actually, let's check if 'x' is in 0..126. Yes.
        # Okay, let's say a variable name is any sequence of alphanumeric chars that isn't JUST a single glyph?
        # No, "3A" is two glyphs.
        # Let's try this: A sequence of glyphs is a literal.
        # If we see "name = ...", the 'name' is the variable.
        # But in "name + 1", 'name' is a literal.
        # This is very confusing if variables and literals use the same charset.
        # Maybe variables are NOT in the alphabet? But A-Z, a-z are in Alphabet.
        # Let's use a simpler heuristic: literals are what the alphabet defines.
        # Let's use a regex to pick up "identifiers" and "literals".
        # If every char is in Alphabet, it's a literal.
        # But then how do we have variables?
        # Maybe variables are IDENTIFIERS that we look up.
        # If it's in the variable map, it's a variable. Otherwise it's a literal?
        # But "3A" is a literal.
        # Let's categorize:
        # 1. Operators: + - * / ( ) = .
        # 2. Literals/Variables: everything else.
        {match, rest} = split_identifier(str)
        [match | tokenize(rest)]
    end
  end

  defp split_identifier(str) do
    # Take contiguous characters that are not operators or whitespace.
    # Stop before 'x' so it remains a separate indeterminate token.
    case Regex.run(~r/^[^\s\(\)\+\-\*\/\.\=\^x\[\]\,]+/, str) do
      [match] -> {match, String.slice(str, String.length(match)..-1//1)}
      nil ->
        if String.starts_with?(str, "x") do
          {"x", String.slice(str, 1..-1//1)}
        else
          {"", str}
        end
    end
  end

  # --- Parser ---

  # Precedence:
  # 1. Assignment (lowest)
  # 2. Addition / Subtraction
  # 3. Multiplication / Division
  # 4. Unary Minus
  # 5. Exponentiation (right-associative)
  # 6. Parens / Literals / Variables (highest)

  defp parse_expression(tokens) do
    case parse_assignment(tokens) do
      {:ok, left, ["=" | rest]} ->
        case parse_expression(rest) do
          {:ok, right, final_rest} ->
            case left do
              {:id, "x"} -> {:error, "Assignment to reserved keyword 'x' is not allowed"}
              {:var, name} -> {:ok, {:assign, name, right}, final_rest}
              {:id, name} -> {:ok, {:assign, name, right}, final_rest}
              {:num, digits} ->
                # If it's a single digit, maybe we allow it as a variable?
                # "x = 5". If x is a digit, we can't assign to it.
                # The user's example "x = 3A + 7" suggests 'x' is a variable name.
                # If 'x' is a glyph, it's a digit.
                # Let's assume if it's on the left of '=', it's a variable name literal string.
                name = digits_to_string(digits)
                if name == "x" do
                  {:error, "Assignment to reserved keyword 'x' is not allowed"}
                else
                  {:ok, {:assign, name, right}, final_rest}
                end
              _ -> {:error, "Invalid assignment target"}
            end
          err -> err
        end
      res -> res
    end
  end

  defp digits_to_string(digits) do
    digits |> Enum.map(&Alphabet.encode/1) |> Enum.join("")
  end

  defp parse_assignment(tokens), do: parse_add_sub(tokens)

  defp parse_add_sub(tokens) do
    case parse_mul_div(tokens) do
      {:ok, left, rest} -> parse_add_sub_loop(left, rest)
      err -> err
    end
  end

  defp parse_add_sub_loop(left, [op | rest]) when op in ["+", "-"] do
    case parse_mul_div(rest) do
      {:ok, right, final_rest} -> parse_add_sub_loop({:op, op, left, right}, final_rest)
      err -> err
    end
  end
  defp parse_add_sub_loop(left, rest), do: {:ok, left, rest}

  defp parse_mul_div(tokens) do
    case parse_unary(tokens) do
      {:ok, left, rest} -> parse_mul_div_loop(left, rest)
      err -> err
    end
  end

  defp parse_mul_div_loop(left, [op | rest]) when op in ["*", "/"] do
    case parse_unary(rest) do
      {:ok, right, final_rest} -> parse_mul_div_loop({:op, op, left, right}, final_rest)
      err -> err
    end
  end
  defp parse_mul_div_loop(left, [token | _] = rest) when token not in ["+", "-", ")", "=", "^", "[", "]", ",", "at", "against", "degree", "roots", "fit"] do
    # Implicit multiplication (juxtaposition)
    case parse_unary(rest) do
      {:ok, right, final_rest} -> parse_mul_div_loop({:op, "*", left, right}, final_rest)
      err -> err
    end
  end
  defp parse_mul_div_loop(left, rest), do: {:ok, left, rest}

  defp parse_unary(["-" | rest]) do
    case parse_pow(rest) do
      {:ok, ast, final_rest} -> {:ok, {:neg, ast}, final_rest}
      err -> err
    end
  end
  defp parse_unary(tokens), do: parse_pow(tokens)

  defp parse_pow(tokens) do
    case parse_primary(tokens) do
      {:ok, left, ["^" | rest]} ->
        # Right-associativity: parse the right side as another power expression.
        case parse_pow(rest) do
          {:ok, right, final_rest} -> {:ok, {:op, "^", left, right}, final_rest}
          err -> err
        end
      res -> res
    end
  end

  defp parse_primary([]), do: {:error, "Unexpected end of input"}
  defp parse_primary(tokens), do: do_parse_primary(tokens)

  defp do_parse_primary(["interpolate" | rest]) do
    # interpolate [(x0, y0), (x1, y1), ...] [at v]
    with {:ok, points, rest2} <- parse_points_list(rest) do
      case rest2 do
        ["at" | rest3] ->
          case parse_expression(rest3) do
            {:ok, v, final_rest} -> {:ok, {:interpolate_at, points, v}, final_rest}
            err -> err
          end
        _ ->
          {:ok, {:interpolate, points}, rest2}
      end
    end
  end

  defp do_parse_primary(["degree" | rest]) do
    case parse_expression(rest) do
      {:ok, poly_expr, final_rest} -> {:ok, {:degree, poly_expr}, final_rest}
      err -> err
    end
  end

  defp do_parse_primary(["roots" | rest]) do
    case parse_expression(rest) do
      {:ok, poly_expr, final_rest} -> {:ok, {:roots, poly_expr}, final_rest}
      err -> err
    end
  end

  defp do_parse_primary(["fit" | rest]) do
    # fit <poly_expr> against [(x0, y0), (x1, y1), ...]
    with {:ok, poly_expr, ["against" | rest2]} <- parse_expression(rest),
         {:ok, points, final_rest} <- parse_points_list(rest2) do
      {:ok, {:fit, poly_expr, points}, final_rest}
    else
      {:ok, _, rest2} -> {:error, "Expected 'against' after fit expression, got: #{inspect(rest2)}"}
      {:error, reason} -> {:error, reason}
    end
  end
  defp do_parse_primary(["(" | rest]) do
    case parse_expression(rest) do
      {:ok, ast, [")" | final_rest]} -> {:ok, ast, final_rest}
      {:ok, _ast, _} -> {:error, "Missing closing parenthesis"}
      err -> err
    end
  end
  defp do_parse_primary([token | rest]) do
    cond do
      # Radix point check
      token =~ ~r/^[^\.\s\(\)\+\-\*\/\=]+\.[^\.\s\(\)\+\-\*\/\=]+$/ ->
        [int_part, frac_part] = String.split(token, ".")
        {:ok, {:rat_literal, parse_digits(int_part), parse_digits(frac_part)}, rest}

      # Just a literal/variable
      token =~ ~r/^[^\.\s\(\)\+\-\*\/\=]+$/ ->
        # Priority 1: Reserved keyword 'x'
        if token == "x" do
          {:ok, {:id, "x"}, rest}
        else
          # Priority 2: Literal number
          # If every character is in the Alphabet, it's a literal number.
          # Otherwise, treat it as an identifier (variable).
          case try_decode_all(token) do
            {:ok, digits} -> {:ok, {:num, digits}, rest}
            :error -> {:ok, {:id, token}, rest}
          end
        end

      true -> {:error, "Unexpected token: #{token}"}
    end
  end


  defp parse_points_list(["[" | rest]) do
    do_parse_points_list(rest, [])
  end
  defp parse_points_list(_), do: {:error, "Expected '[' for points list"}

  defp do_parse_points_list(["]" | rest], acc), do: {:ok, Enum.reverse(acc), rest}
  defp do_parse_points_list(["(" | rest], acc) do
    with {:ok, x, ["," | rest2]} <- parse_expression(rest),
         {:ok, y, [")" | rest3]} <- parse_expression(rest2) do
      # Optional comma between points
      case rest3 do
        ["," | rest4] -> do_parse_points_list(rest4, [{x, y} | acc])
        _ -> do_parse_points_list(rest3, [{x, y} | acc])
      end
    else
      {:ok, _, [token | _]} -> {:error, "Unexpected token in point: #{token}"}
      {:ok, _, []} -> {:error, "Unexpected end of input in point"}
      {:error, reason} -> {:error, reason}
    end
  end
  defp do_parse_points_list([token | _], _), do: {:error, "Unexpected token in points list: #{token}"}
  defp do_parse_points_list([], _), do: {:error, "Unexpected end of input in points list"}

  defp parse_digits(str) do
    str
    |> String.graphemes()
    |> Enum.map(&Alphabet.decode/1)
    |> Enum.reverse()
  end

  defp try_decode_all(str) do
    try do
      {:ok, parse_digits(str)}
    rescue
      _ -> :error
    end
  end

  # Post-processing helper to differentiate :id into :num or :var
  # Actually, the requirement says Parser returns {:num, digits}.
  # Let's adjust: if all chars are in Alphabet, it's {:num, digits}.
  # Wait, then how to have variables?
  # "Maintain a session state map... variable binding... x = 3A + 7".
  # If 'x' is a glyph (it is, value 59), then ANY single glyph is a number.
  # This makes variables impossible unless they are NOT in the alphabet.
  # But the alphabet covers most printable chars!
  # Let's check the alphabet again. It has 127 chars.
  # Maybe variables are strings that are NOT single glyphs?
  # Or maybe we check the session map during evaluation.
  # Let's make the parser return {:id, name} for any alphanumeric sequence.
  # And have a pass or handle it in Evaluator.
end
