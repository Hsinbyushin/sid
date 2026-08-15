alias Sid.Imports.Extractors.Docx

defmodule Sid.DocxPreview do
  @moduledoc false

  @preview_count 40

  def run([path]) do
    IO.puts("Extracting DOCX paragraphs...")
    IO.puts("Source: #{path}")
    IO.puts("")

    case Docx.extract(path) do
      {:ok, paragraphs} ->
        print_preview(paragraphs)

      {:error, reason} ->
        IO.puts(:stderr, "DOCX extraction failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  def run(_args) do
    IO.puts("""
    Usage:

        mix run scripts/preview_docx.exs PATH_TO_DOCX
    """)

    System.halt(1)
  end

  defp print_preview(paragraphs) do
    IO.puts("Extracted #{length(paragraphs)} paragraph(s).")
    IO.puts("")
    IO.puts("=== DOCX Paragraph Preview ===")
    IO.puts("")

    paragraphs
    |> Enum.take(@preview_count)
    |> Enum.each(&print_paragraph/1)

    remaining = length(paragraphs) - @preview_count

    if remaining > 0 do
      IO.puts("")
      IO.puts("... #{remaining} additional paragraph(s) not shown.")
    end
  end

  defp print_paragraph(paragraph) do
    index =
      paragraph.index
      |> Integer.to_string()
      |> String.pad_leading(4)

    style =
      paragraph.style
      |> display_style()
      |> String.pad_trailing(16)

    IO.puts("#{index}  #{style}  #{preview_text(paragraph.text)}")
  end

  defp display_style(nil), do: "—"
  defp display_style(""), do: "—"
  defp display_style(style), do: style

  defp preview_text(""), do: "∅"

  defp preview_text(text) do
    normalized =
    text
    |> String.replace("\n", " ⏎ ")
    |> String.replace("\t", " ⇥ ")
    |> String.replace(~r/[ ]+/u, " ")
    |> String.trim()

    if String.length(normalized) > 160 do
      String.slice(normalized, 0, 160) <> "…"
    else
      normalized
    end
  end
end

Sid.DocxPreview.run(System.argv())
