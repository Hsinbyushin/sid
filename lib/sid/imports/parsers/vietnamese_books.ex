defmodule Sid.Imports.Parsers.VietnameseBooks do
  @moduledoc """
  Deterministic parser for the structured Vietnamese books spreadsheets.

  The parser operates on a `SourceRecord` whose raw value is a map representing
  one spreadsheet row.

  It deliberately does not read XLSX files itself. Spreadsheet extraction and
  vendor-specific interpretation are separate responsibilities.

  Source values are preserved in the `SourceRecord`. The parser only adds a
  structured interpretation in the form of an `ExtractedOffer`.

  No LLM or probabilistic extraction is involved.
  """
  @behaviour Sid.Imports.Parser

  alias Sid.Imports.{
    ExtractedOffer,
    Identifier,
    SourceRecord,
    TextContent
  }

  @impl true
  @spec parse(SourceRecord.t()) ::
          {:ok, ExtractedOffer.t()} | {:error, term()}
  def parse(%SourceRecord{raw: raw} = source) when is_map(raw) do
    {:ok,
     %ExtractedOffer{
       source: source,
       vendor_code: text_value(raw, "Code"),
       titles: extract_titles(raw),
       descriptions: extract_descriptions(raw),
       responsibility_statement: text_value(raw, "Authors"),
       publication_statement: publication_statement(raw),
       physical_description: physical_description(raw),
       identifiers: extract_identifiers(raw),
       language_statements: extract_language_statements(raw),
       price_amount: decimal_value(raw, "Price in EUR"),
       price_currency: price_currency(raw)
     }}
  end

  def parse(%SourceRecord{}) do
    {:error, :invalid_raw_record}
  end

  defp extract_titles(raw) do
    []
    |> maybe_add_text(:primary_title, text_value(raw, "Title"))
    |> maybe_add_text(
      :translated_title,
      text_value(raw, "Title (TRANSLATION)")
    )
  end

  defp extract_descriptions(raw) do
    description =
      first_present(raw, [
        "Content ",
        "Content"
      ])

    maybe_add_text([], :description, description)
  end

  defp extract_identifiers(raw) do
    case text_value(raw, "ISBN") do
      nil ->
        []

      value ->
        [
          %Identifier{
            scheme: :isbn,
            value: value,
            validation_status: :unchecked
          }
        ]
    end
  end

  defp extract_language_statements(raw) do
    case text_value(raw, "Language") do
      nil -> []
      language -> [language]
    end
  end

  defp publication_statement(raw) do
    publisher = text_value(raw, "Publisher")
    year = text_value(raw, "Year")

    [publisher, year]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      parts -> Enum.join(parts, ", ")
    end
  end

  defp physical_description(raw) do
    pages = text_value(raw, "Pages")
    size = text_value(raw, "Size")

    case {pages, size} do
      {nil, nil} ->
        nil

      {pages, nil} ->
        "Pages: #{pages}"

      {nil, size} ->
        "Size: #{size}"

      {pages, size} ->
        "Pages: #{pages}; Size: #{size}"
    end
  end

  defp price_currency(raw) do
    if present?(Map.get(raw, "Price in EUR")) do
      "EUR"
    end
  end

  defp decimal_value(raw, key) do
    case Map.get(raw, key) do
      nil ->
        nil

      %Decimal{} = decimal ->
        Decimal.round(decimal, 2)

      value when is_integer(value) ->
        Decimal.new(value)

      value when is_float(value) ->
        Decimal.from_float(value)
        |> Decimal.round(2)

      value when is_binary(value) ->
        value
        |> String.trim()
        |> case do
          "" ->
            nil

          value ->
            case Decimal.parse(value) do
              {decimal, ""} -> decimal
              _ -> nil
            end
        end

      _ ->
        nil
    end
  end

  defp first_present(raw, keys) do
    Enum.find_value(keys, fn key ->
      case text_value(raw, key) do
        nil -> false
        value -> value
      end
    end)
  end

  defp text_value(raw, key) do
    raw
    |> Map.get(key)
    |> normalize_text_value()
  end

  defp normalize_text_value(nil), do: nil

  defp normalize_text_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text_value(%Decimal{} = value) do
    Decimal.to_string(value, :normal)
  end

  defp normalize_text_value(value)
       when is_integer(value) or is_float(value) do
    to_string(value)
  end

  defp normalize_text_value(value), do: to_string(value)

  defp maybe_add_text(contents, _role, nil), do: contents

  defp maybe_add_text(contents, role, text) do
    contents ++
      [
        %TextContent{
          role: role,
          text: text
        }
      ]
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true
end
