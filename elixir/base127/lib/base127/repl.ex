defmodule Base127.REPL do
  @moduledoc """
  Interactive REPL for Base-127 language.
  """

  alias Base127.{Parser, Evaluator, Renderer}

  @doc "Starts the REPL loop."
  def start do
    require Logger
    Logger.configure(level: :error)
    IO.puts("Base-127 Formal Language Runtime")
    IO.puts("Type expressions or commands (e.g., :approx 5 1/3, :vars, :clear).")
    loop(%{})
  end

  defp loop(vars) do
    case IO.gets("127> ") do
      :eof -> 
        IO.puts("\nGoodbye.")
        :ok
      {:error, reason} ->
        IO.puts("Error: #{reason}")
        :ok
      line ->
        line = String.trim(line)
        cond do
          line == "" ->
            loop(vars)
          line == ":clear" ->
            IO.puts("Session cleared.")
            loop(%{})
          line == ":cls" ->
            IO.write([IO.ANSI.clear(), IO.ANSI.home()])
            loop(vars)
          true ->
            {new_vars, _} = handle_line(line, vars)
            loop(new_vars)
        end
    end
  end

  defp handle_line(":vars", vars) do
    if map_size(vars) == 0 do
      IO.puts("No variables bound.")
    else
      Enum.each(vars, fn {name, val} ->
        IO.puts("#{name} = #{Renderer.render(val)}")
      end)
    end
    {vars, nil}
  end

  defp handle_line(line, vars) do
    if String.starts_with?(line, ":approx") do
      handle_approx_command(line, vars)
    else
      case Parser.parse(line) do
        {:ok, ast} ->
          case Evaluator.eval_with_vars(ast, vars) do
            {:ok, val, updated_vars} ->
              IO.puts(Renderer.render(val))
              {updated_vars, val}
            {:error, reason} ->
              IO.puts("Evaluation Error: #{reason}")
              {vars, nil}
          end
        {:error, reason} ->
          IO.puts("Parse Error: #{reason}")
          {vars, nil}
      end
    end
  end

  defp handle_approx_command(line, vars) do
    # Expected: :approx N expression
    parts = String.split(line, " ", parts: 3)
    case parts do
      [":approx", n_str, expr_str] ->
        case Integer.parse(n_str) do
          {n, ""} ->
            case Parser.parse(expr_str) do
              {:ok, ast} ->
                case Evaluator.eval_with_vars(ast, vars) do
                  {:ok, val, updated_vars} ->
                    IO.puts(Renderer.approx(val, n))
                    {updated_vars, val}
                  {:error, reason} ->
                    IO.puts("Evaluation Error: #{reason}")
                    {vars, nil}
                end
              {:error, reason} ->
                IO.puts("Parse Error: #{reason}")
                {vars, nil}
            end
          _ ->
            IO.puts("Invalid precision: #{n_str}")
            {vars, nil}
        end
      _ ->
        IO.puts("Usage: :approx N expression")
        {vars, nil}
    end
  end
end
