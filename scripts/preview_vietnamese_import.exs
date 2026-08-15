alias Sid.Imports
alias Sid.Imports.Extractors.Xlsx
alias Sid.Imports.Parsers.VietnameseBooks

defmodule Sid.ImportPreview do
  @moduledoc false

  @preview_count 3

  def run([path]) do
    path
    |> extract()
    |> parse()
    |> print_summary(path)
  end

  def run(_args) do
    IO.puts("""
    Usage:

        mix run scripts/preview_vietnamese_import.exs -- PATH_TO_XLSX

    Example:

        mix run scripts/preview_vietnamese_import.exs -- \
          tmp/import_samples/Buecherliste-5-2026.xlsx
    """)

    System.halt(1)
  end

  defp extract(path) do
    IO.puts("Extracting XLSX source records...")
    IO.puts("Source: #{path}")
    IO.puts("")

    case Xlsx.extract(
           path,
           vendor: "Vietnamese Books Vendor",
           header_row: 2
         ) do
      {:ok, source_records} ->
        IO.puts("Extracted #{length(source_records)} source record(s).")

        {:ok, source_records}

      {:error, reason} ->
        fail("XLSX extraction failed", reason)
    end
  end

  defp parse({:ok, source_records}) do
    {successful, failed} =
      Imports.process_many(
        source_records,
        VietnameseBooks
      )

    IO.puts(
      "Parsed #{length(successful)} offer(s) successfully."
    )

    if failed != [] do
      IO.puts(
        "Failed to parse #{length(failed)} source record(s)."
      )
    end

    IO.puts("")

    {:ok, successful, failed}
  end

  defp print_summary(
         {:ok, offers, failed},
         path
       ) do
    IO.puts("=== SID Import Preview ===")
    IO.puts("")
    IO.puts("File: #{Path.basename(path)}")
    IO.puts("Parsed offers: #{length(offers)}")
    IO.puts("Parse failures: #{length(failed)}")
    IO.puts("")

    offers
    |> Enum.take(@preview_count)
    |> Enum.with_index(1)
    |> Enum.each(fn {offer, index} ->
      print_offer(offer, index)
    end)

    if length(offers) > @preview_count do
      IO.puts("... #{length(offers) - @preview_count} additional offer(s) not shown.")
    end

    print_failures(failed)
  end

  defp print_offer(offer, index) do
    IO.puts("--- Offer #{index} ---")

    IO.puts("Location: #{format_locator(offer.source.locator)}")

    IO.puts("Vendor code: #{display(offer.vendor_code)}")

    print_texts("Titles", offer.titles)
    print_texts("Descriptions", offer.descriptions)

    IO.puts("Responsibility: #{display(offer.responsibility_statement)}")

    IO.puts("Publication: #{display(offer.publication_statement)}")

    IO.puts("Physical: #{display(offer.physical_description)}")

    IO.puts("Languages: #{format_list(offer.language_statements)}")

    IO.puts("Identifiers: #{format_identifiers(offer.identifiers)}")

    IO.puts("Price: #{format_price(offer.price_amount, offer.price_currency)}")

    IO.puts("Raw source columns: #{map_size(offer.source.raw)}")

    IO.puts("")
  end

  defp print_texts(label, []) do
    IO.puts("#{label}: —")
  end

  defp print_texts(label, texts) do
    IO.puts("#{label}:")

    Enum.each(texts, fn text_content ->
      language =
        case text_content.language do
          nil -> ""
          value -> " [#{value}]"
        end

      IO.puts("  - #{text_content.role}#{language}: #{preview_text(text_content.text)}")
    end)
  end

  defp preview_text(text) when is_binary(text) do
    normalized =
      text
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if String.length(normalized) > 240 do
      String.slice(normalized, 0, 240) <> "…"
    else
      normalized
    end
  end

  defp format_locator(locator) do
    locator
    |> Enum.sort()
    |> Enum.map_join(", ", fn {key, value} ->
      "#{key}=#{value}"
    end)
  end

  defp format_identifiers([]), do: "—"

  defp format_identifiers(identifiers) do
    Enum.map_join(identifiers, ", ", fn identifier ->
      "#{identifier.scheme}:#{identifier.value} (#{identifier.validation_status})"
    end)
  end

  defp format_list([]), do: "—"
  defp format_list(values), do: Enum.join(values, ", ")

  defp format_price(nil, _currency), do: "—"

  defp format_price(amount, currency) do
    amount =
      Decimal.to_string(amount, :normal)

    case currency do
      nil -> amount
      value -> "#{amount} #{value}"
    end
  end

  defp display(nil), do: "—"
  defp display(value), do: value

  defp print_failures([]), do: :ok

  defp print_failures(failed) do
    IO.puts("")
    IO.puts("=== Parse Failures ===")

    Enum.each(failed, fn {source_record, reason} ->
      IO.puts("#{format_locator(source_record.locator)}: #{inspect(reason)}")
    end)
  end

  defp fail(message, reason) do
    IO.puts(:stderr, "#{message}: #{inspect(reason)}")
    System.halt(1)
  end
end

Sid.ImportPreview.run(System.argv())
