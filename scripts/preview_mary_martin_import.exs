alias Sid.Imports
alias Sid.Imports.Extractors.Docx
alias Sid.Imports.Parsers.MaryMartin
alias Sid.Imports.Segmenters.MaryMartinDocx

defmodule Sid.MaryMartinImportPreview do
  @moduledoc false

  @preview_count 5

  def run([path]) do
    with {:ok, paragraphs} <- Docx.extract(path),
         {:ok, source_records} <-
           MaryMartinDocx.segment(
             paragraphs,
             Path.basename(path)
           ) do
      {offers, failures} =
        Imports.process_many(
          source_records,
          MaryMartin
        )

      print_summary(
        path,
        paragraphs,
        source_records,
        offers,
        failures
      )
    else
      {:error, reason} ->
        IO.puts(:stderr, "Import preview failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  def run(_args) do
    IO.puts("""
    Usage:

        mix run scripts/preview_mary_martin_import.exs PATH_TO_DOCX
    """)

    System.halt(1)
  end

  defp print_summary(
         path,
         paragraphs,
         source_records,
         offers,
         failures
       ) do
    IO.puts("=== SID Mary Martin Import Preview ===")
    IO.puts("")
    IO.puts("File: #{Path.basename(path)}")
    IO.puts("Paragraphs: #{length(paragraphs)}")
    IO.puts("Candidate records: #{length(source_records)}")
    IO.puts("Parsed offers: #{length(offers)}")
    IO.puts("Rejected/failed candidates: #{length(failures)}")
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

    print_quality_summary(offers)
    print_diagnostics(offers, paragraphs)
    print_failures(failures)
  end

  defp print_quality_summary(offers) do
    total = length(offers)

    with_category =
      Enum.count(offers, &present?(&1.vendor_category))

    with_identifiers =
      Enum.count(offers, &(&1.identifiers != []))

    identifier_statuses =
      offers
      |> Enum.flat_map(& &1.identifiers)
      |> Enum.frequencies_by(& &1.validation_status)

    with_price =
      Enum.count(offers, &(not is_nil(&1.price_amount)))

    with_descriptions =
      Enum.count(offers, &(&1.descriptions != []))

    offers_with_unparsed =
      Enum.count(offers, &(&1.unparsed != []))

    unparsed_values =
      offers
      |> Enum.flat_map(& &1.unparsed)

    IO.puts("")
    IO.puts("=== Import Quality Summary ===")
    IO.puts("")

    print_metric("Offers", total)

    IO.puts("")

    print_metric("With category", with_category)
    print_metric("Without category", total - with_category)

    IO.puts("")

    print_metric("With identifiers", with_identifiers)
    print_metric("Without identifiers", total - with_identifiers)

    identifier_statuses
    |> Enum.sort_by(fn {status, _count} -> status end)
    |> Enum.each(fn {status, count} ->
      print_metric("Identifiers #{status}", count)
    end)

    IO.puts("")

    print_metric("With price", with_price)
    print_metric("Without price", total - with_price)

    IO.puts("")

    print_metric("With descriptions", with_descriptions)
    print_metric("Without descriptions", total - with_descriptions)

    IO.puts("")

    print_metric("With unparsed data", offers_with_unparsed)
    print_metric("Cleanly parsed", total - offers_with_unparsed)
    print_metric("Unparsed statements", length(unparsed_values))

    print_common_unparsed(unparsed_values)
  end

  defp print_diagnostics(offers, paragraphs) do
    print_offer_group(
      "Offers With Unparsed Data",
      Enum.filter(offers, &(&1.unparsed != []))
    )

    offers_without_identifiers =
      Enum.filter(offers, &(&1.identifiers == []))

    print_offer_group(
      "Offers Without Identifiers",
      offers_without_identifiers
    )

    invalid_identifier_offers =
      Enum.filter(offers, fn offer ->
        Enum.any?(
          offer.identifiers,
          &(&1.validation_status == :invalid)
        )
      end)

    print_offer_group(
      "Offers With Invalid Identifiers",
      invalid_identifier_offers
    )

    print_raw_sources(offers_without_identifiers, paragraphs)
  end

  defp print_raw_sources([], _paragraphs), do: :ok

  defp print_raw_sources(offers, paragraphs) do
    paragraphs_by_index =
      Map.new(paragraphs, fn paragraph ->
        {paragraph.index, paragraph}
      end)

    IO.puts("")
    IO.puts("=== Raw Source For Offers Without Identifiers ===")
    IO.puts("")

    Enum.each(offers, fn offer ->
      start_index = offer.source.locator[:paragraph_start]
      end_index = offer.source.locator[:paragraph_end]

      IO.puts("--- paragraphs #{start_index}-#{end_index} ---")

      Enum.each(start_index..end_index, fn index ->
        case Map.get(paragraphs_by_index, index) do
          nil ->
            IO.puts("#{index}: <missing>")

          paragraph ->
            IO.puts("#{index}: #{raw_paragraph_text(paragraph.text)}")
        end
      end)

      IO.puts("")
    end)
  end

  defp raw_paragraph_text(text) when is_binary(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.replace("\n", " ⏎ ")
  end

  defp raw_paragraph_text(nil), do: "∅"

  defp print_offer_group(_label, []), do: :ok

  defp print_offer_group(label, offers) do
    IO.puts("")
    IO.puts("=== #{label} ===")
    IO.puts("Count: #{length(offers)}")
    IO.puts("")

    Enum.each(offers, &print_diagnostic_offer/1)
  end

  defp print_diagnostic_offer(offer) do
    IO.puts("--- #{format_locator(offer.source.locator)} ---")
    IO.puts("Title: #{diagnostic_title(offer)}")
    IO.puts("Category: #{display(offer.vendor_category)}")
    IO.puts("Identifiers: #{format_identifiers(offer.identifiers)}")
    IO.puts("Unparsed: #{format_list(offer.unparsed)}")
    IO.puts("")
  end

  defp diagnostic_title(%{titles: []}), do: "—"

  defp diagnostic_title(%{titles: titles}) do
    case Enum.find(titles, &(&1.role == :primary_title)) do
      nil ->
        titles
        |> List.first()
        |> Map.get(:text)
        |> display()

      title ->
        display(title.text)
    end
  end

  defp print_common_unparsed([]), do: :ok

  defp print_common_unparsed(values) do
    IO.puts("")
    IO.puts("Most common unparsed values:")

    values
    |> Enum.frequencies()
    |> Enum.sort_by(fn {value, count} ->
      {-count, value}
    end)
    |> Enum.take(10)
    |> Enum.each(fn {value, count} ->
      IO.puts("  #{count} × #{preview_text(value)}")
    end)
  end

  defp print_metric(label, value) do
    IO.puts("#{String.pad_trailing(label <> ":", 24)} #{value}")
  end

  defp present?(value) when is_binary(value) do
    String.trim(value) != ""
  end

  defp present?(_value), do: false

  defp print_offer(offer, index) do
    IO.puts("--- Offer #{index} ---")

    IO.puts("Location: #{format_locator(offer.source.locator)}")

    IO.puts("Category: #{display(offer.vendor_category)}")

    print_titles(offer.titles)

    IO.puts("Responsibility: #{display(offer.responsibility_statement)}")

    IO.puts("Publication: #{display(offer.publication_statement)}")

    IO.puts("Physical: #{display(offer.physical_description)}")

    IO.puts("Edition: #{display(offer.edition_statement)}")

    IO.puts("Series: #{format_list(offer.series_statements)}")

    IO.puts("Notes: #{format_list(offer.notes)}")

    IO.puts("Subjects: #{format_list(offer.subjects)}")

    IO.puts("Identifiers: #{format_identifiers(offer.identifiers)}")

    IO.puts("Price: #{format_price(offer.price_amount, offer.price_currency)}")

    IO.puts("Binding: #{display(offer.binding)}")

    IO.puts("Weight: #{display(offer.weight)}")

    IO.puts("URL: #{display(offer.vendor_url)}")

    print_descriptions(offer.descriptions)

    IO.puts("Unparsed: #{format_unparsed(offer.unparsed)}")

    IO.puts("")
  end

  defp print_titles([]) do
    IO.puts("Titles: —")
  end

  defp print_titles(titles) do
    IO.puts("Titles:")

    Enum.each(titles, fn title ->
      IO.puts("  - #{title.role}: #{preview_text(title.text)}")
    end)
  end

  defp print_descriptions([]) do
    IO.puts("Descriptions: —")
  end

  defp print_descriptions(descriptions) do
    IO.puts("Descriptions:")

    Enum.each(descriptions, fn description ->
      IO.puts("  - #{preview_text(description.text)}")
    end)
  end

  defp print_failures([]), do: :ok

  defp print_failures(failures) do
    IO.puts("")
    IO.puts("=== Rejected / Failed Candidates ===")

    Enum.each(failures, fn {source_record, reason} ->
      IO.puts("#{format_locator(source_record.locator)}: #{inspect(reason)}")
    end)
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

  defp format_price(nil, _currency), do: "—"

  defp format_price(amount, currency) do
    amount =
      Decimal.to_string(amount, :normal)

    case currency do
      nil -> amount
      value -> "#{amount} #{value}"
    end
  end

  defp format_list([]), do: "—"
  defp format_list(values), do: Enum.join(values, " | ")

  defp format_unparsed([]), do: "—"
  defp format_unparsed(values), do: Enum.join(values, " | ")

  defp preview_text(text) do
    normalized =
      text
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if String.length(normalized) > 220 do
      String.slice(normalized, 0, 220) <> "…"
    else
      normalized
    end
  end

  defp display(nil), do: "—"
  defp display(value), do: value
end

Sid.MaryMartinImportPreview.run(System.argv())
