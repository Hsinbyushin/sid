alias Sid.Imports.Extractors.Docx
alias Sid.Imports.Segmenters.MaryMartinDocx

defmodule Sid.MaryMartinSegmentPreview do
  @moduledoc false

  @preview_count 6

  def run([path]) do
    with {:ok, paragraphs} <- Docx.extract(path),
         {:ok, records} <-
           MaryMartinDocx.segment(
             paragraphs,
             Path.basename(path)
           ) do
      print_summary(paragraphs, records)
    else
      {:error, reason} ->
        IO.puts(:stderr, "Preview failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  def run(_args) do
    IO.puts("""
    Usage:

        mix run scripts/preview_mary_martin_segments.exs PATH_TO_DOCX
    """)

    System.halt(1)
  end

  defp print_summary(paragraphs, records) do
    IO.puts("=== Mary Martin DOCX Segmentation Preview ===")
    IO.puts("")
    IO.puts("Paragraphs: #{length(paragraphs)}")
    IO.puts("Candidate records: #{length(records)}")
    IO.puts("")

    records
    |> Enum.take(@preview_count)
    |> Enum.with_index(1)
    |> Enum.each(fn {record, index} ->
      print_record(record, index)
    end)

    remaining = length(records) - @preview_count

    if remaining > 0 do
      IO.puts("... #{remaining} additional candidate record(s) not shown.")
    end
  end

  defp print_record(record, index) do
    IO.puts("--- Candidate #{index} ---")

    IO.puts("Paragraphs: #{record.locator.paragraph_start}-#{record.locator.paragraph_end}")

    IO.puts("Category: #{record.metadata.vendor_category || "—"}")

    IO.puts("Paragraph count: #{length(record.raw)}")

    IO.puts("")

    Enum.each(record.raw, fn paragraph ->
      style =
        case paragraph.style do
          nil -> "—"
          "" -> "—"
          value -> value
        end

      IO.puts("  #{paragraph.index} [#{style}] #{preview_text(paragraph.text)}")
    end)

    IO.puts("")
  end

  defp preview_text(""), do: "∅"

  defp preview_text(text) do
    normalized =
      text
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if String.length(normalized) > 180 do
      String.slice(normalized, 0, 180) <> "…"
    else
      normalized
    end
  end
end

Sid.MaryMartinSegmentPreview.run(System.argv())
