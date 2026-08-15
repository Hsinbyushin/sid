defmodule Sid.Imports.Segmenters.MaryMartinDocx do
  @moduledoc """
  Segments paragraphs from Mary Martin DOCX files into source records.

  Record boundaries are identified by separator paragraphs consisting of
  repeated hyphens or underscores.

  Heading1 paragraphs are treated as optional category context. They are not
  required for record detection and are not themselves included in an offer's
  raw paragraphs.

  Bibliographic interpretation is deliberately left to the Mary Martin parser.
  """

  alias Sid.Imports.Extractors.Docx.Paragraph
  alias Sid.Imports.SourceRecord

  @spec segment([Paragraph.t()], String.t(), keyword()) ::
          {:ok, [SourceRecord.t()]}
  def segment(paragraphs, source_filename, opts \\ [])
      when is_list(paragraphs) and is_binary(source_filename) do
    state = %{
      category: nil,
      current: [],
      records: [],
      source_filename: source_filename,
      vendor: Keyword.get(opts, :vendor, "Mary Martin Booksellers")
    }

    records =
      paragraphs
      |> Enum.reduce(state, &consume/2)
      |> finish_record()
      |> Map.fetch!(:records)
      |> Enum.reverse()

    {:ok, records}
  end

  defp consume(
         %Paragraph{style: "Heading1"} = paragraph,
         state
       ) do
    state
    |> finish_record()
    |> Map.put(:category, normalize(paragraph.text))
  end

  defp consume(%Paragraph{} = paragraph, state) do
    if separator?(paragraph.text) do
      finish_record(state)
    else
      %{state | current: [paragraph | state.current]}
    end
  end

  defp finish_record(%{current: []} = state), do: state

  defp finish_record(state) do
    paragraphs =
      state.current
      |> Enum.reverse()
      |> trim_empty_edges()

    if meaningful?(paragraphs) do
      record =
        source_record(
          paragraphs,
          state.category,
          state.source_filename,
          state.vendor
        )

      %{
        state
        | current: [],
          records: [record | state.records]
      }
    else
      %{state | current: []}
    end
  end

  defp source_record(paragraphs, category, filename, vendor) do
    %SourceRecord{
      format: :docx,
      source_filename: filename,
      vendor: vendor,
      locator: %{
        paragraph_start: List.first(paragraphs).index,
        paragraph_end: List.last(paragraphs).index
      },
      raw: paragraphs,
      metadata: %{
        vendor_category: category
      }
    }
  end

  defp separator?(text) do
    text = String.trim(text)

    String.length(text) >= 20 and
      text
      |> String.graphemes()
      |> Enum.all?(&(&1 in ["-", "_"]))
  end

  defp meaningful?(paragraphs) do
    Enum.any?(paragraphs, &(normalize(&1.text) != ""))
  end

  defp trim_empty_edges(paragraphs) do
    paragraphs
    |> Enum.drop_while(&(normalize(&1.text) == ""))
    |> Enum.reverse()
    |> Enum.drop_while(&(normalize(&1.text) == ""))
    |> Enum.reverse()
  end

  defp normalize(text), do: String.trim(text)
end
