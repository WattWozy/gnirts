defmodule Base127.Alphabet do
  @moduledoc """
  The canonical glyph registry for Base-127.
  Maps values 0..126 to unique printable characters.
  """

  # 0-9: "0123456789" (10)
  # 10-35: "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (26)
  # 36-61: "abcdefghijklmnopqrstuvwxyz" (26)
  # 62-126: Special printable Unicode (65)
  @alphabet_string "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" <>
    "αβγδεζηθικλμνξοπρστυφχψω" <> # Greek lowercase (24)
    "ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ" <> # Greek uppercase (24)
    "∑∏∫√∞∆∇∂≈≠≤≥" <>             # Math (12)
    "■□▲△▼"                       # Geometric (5)
    # Total: 10 + 26 + 26 + 24 + 24 + 12 + 5 = 127

  @alphabet String.graphemes(@alphabet_string)

  @encode_map @alphabet |> Enum.with_index() |> Map.new(fn {char, i} -> {i, char} end)
  @decode_map @alphabet |> Enum.with_index() |> Map.new()

  @doc "Encodes a value 0..126 to its canonical glyph."
  @spec encode(0..126) :: String.t()
  def encode(n) when n in 0..126, do: Map.fetch!(@encode_map, n)

  @doc "Decodes a canonical glyph to its value 0..126."
  @spec decode(String.t()) :: 0..126
  def decode(glyph), do: Map.fetch!(@decode_map, glyph)

  @doc "Returns the full alphabet as a list of glyphs."
  def alphabet, do: @alphabet
end
