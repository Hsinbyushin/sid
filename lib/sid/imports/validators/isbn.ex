defmodule Sid.Imports.Validators.Isbn do
  @moduledoc """
  Deterministic validation for ISBN-10 and ISBN-13 identifiers.

  Validation ignores formatting characters commonly used when displaying an
  ISBN, currently hyphens and whitespace.

  The validator does not correct identifiers and does not replace the original
  source value. It only determines whether the supplied value satisfies the
  ISBN checksum rules.
  """

  @spec valid?(String.t()) :: boolean()
  def valid?(value) when is_binary(value) do
    case normalized_digits(value) do
      isbn when byte_size(isbn) == 10 ->
        valid_isbn10?(isbn)

      isbn when byte_size(isbn) == 13 ->
        valid_isbn13?(isbn)

      _ ->
        false
    end
  end

  def valid?(_value), do: false

  defp normalized_digits(value) do
    value
    |> String.replace(~r/[\s-]+/u, "")
    |> String.upcase()
  end

  defp valid_isbn10?(isbn) do
    characters = String.graphemes(isbn)

    with true <- valid_isbn10_characters?(characters),
         values <- isbn10_values(characters) do
      values
      |> Enum.with_index(1)
      |> Enum.reduce(0, fn {value, position}, sum ->
        sum + position * value
      end)
      |> rem(11)
      |> Kernel.==(0)
    else
      _ -> false
    end
  end

  defp valid_isbn10_characters?(characters) do
    case characters do
      [
        d1,
        d2,
        d3,
        d4,
        d5,
        d6,
        d7,
        d8,
        d9,
        check
      ] ->
        Enum.all?(
          [d1, d2, d3, d4, d5, d6, d7, d8, d9],
          &digit?/1
        ) and
          (digit?(check) or check == "X")

      _ ->
        false
    end
  end

  defp isbn10_values(characters) do
    {digits, [check]} = Enum.split(characters, 9)

    Enum.map(digits, &String.to_integer/1) ++
      [
        if(check == "X",
          do: 10,
          else: String.to_integer(check)
        )
      ]
  end

  defp valid_isbn13?(isbn) do
    characters = String.graphemes(isbn)

    if length(characters) == 13 and
         Enum.all?(characters, &digit?/1) do
      characters
      |> Enum.map(&String.to_integer/1)
      |> Enum.with_index()
      |> Enum.reduce(0, fn {digit, index}, sum ->
        weight =
          if rem(index, 2) == 0 do
            1
          else
            3
          end

        sum + digit * weight
      end)
      |> rem(10)
      |> Kernel.==(0)
    else
      false
    end
  end

  defp digit?(character) do
    character in ~w(0 1 2 3 4 5 6 7 8 9)
  end
end
