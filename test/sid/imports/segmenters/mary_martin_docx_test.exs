defmodule Sid.Imports.Segmenters.MaryMartinDocxTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Extractors.Docx.Paragraph
  alias Sid.Imports.Segmenters.MaryMartinDocx

  test "segments offers at separator paragraphs" do
    paragraphs = [
      p(1, "First title"),
      p(2, "9789998400962"),
      p(3, "$ 25.00 / PB"),
      p(4, String.duplicate("-", 40)),
      p(5, "Second title"),
      p(6, "9789998400436"),
      p(7, "$ 35.00 / PB"),
      p(8, String.duplicate("-", 30))
    ]

    assert {:ok, [first, second]} =
             MaryMartinDocx.segment(paragraphs, "vendor.docx")

    assert Enum.map(first.raw, & &1.text) == [
             "First title",
             "9789998400962",
             "$ 25.00 / PB"
           ]

    assert Enum.map(second.raw, & &1.text) == [
             "Second title",
             "9789998400436",
             "$ 35.00 / PB"
           ]
  end

  test "carries Heading1 category context into following records" do
    paragraphs = [
      p(1, "History", "Heading1"),
      p(2, ""),
      p(3, "First history title"),
      p(4, String.duplicate("-", 30)),
      p(5, "Second history title"),
      p(6, String.duplicate("-", 30)),
      p(7, "Literature", "Heading1"),
      p(8, "A literary title"),
      p(9, String.duplicate("-", 30))
    ]

    assert {:ok, [first, second, third]} =
             MaryMartinDocx.segment(paragraphs, "vendor.docx")

    assert first.metadata.vendor_category == "History"
    assert second.metadata.vendor_category == "History"
    assert third.metadata.vendor_category == "Literature"
  end

  test "does not require a Heading1 before the first record" do
    paragraphs = [
      p(1, "A title without a category"),
      p(2, "9789998400962"),
      p(3, String.duplicate("_", 30))
    ]

    assert {:ok, [record]} =
             MaryMartinDocx.segment(paragraphs, "vendor.docx")

    assert record.metadata.vendor_category == nil
    assert List.first(record.raw).text == "A title without a category"
  end

  test "accepts separators of different lengths and characters" do
    paragraphs = [
      p(1, "First"),
      p(2, String.duplicate("-", 20)),
      p(3, "Second"),
      p(4, String.duplicate("_", 45))
    ]

    assert {:ok, [first, second]} =
             MaryMartinDocx.segment(paragraphs, "vendor.docx")

    assert List.first(first.raw).text == "First"
    assert List.first(second.raw).text == "Second"
  end

  test "preserves empty paragraphs inside a record" do
    paragraphs = [
      p(10, "Title"),
      p(11, ""),
      p(12, "Description"),
      p(13, String.duplicate("-", 30))
    ]

    assert {:ok, [record]} =
             MaryMartinDocx.segment(paragraphs, "vendor.docx")

    assert Enum.map(record.raw, & &1.text) == [
             "Title",
             "",
             "Description"
           ]

    assert record.locator == %{
             paragraph_start: 10,
             paragraph_end: 12
           }
  end

  test "trims empty paragraphs from record edges" do
    paragraphs = [
      p(1, ""),
      p(2, "Title"),
      p(3, ""),
      p(4, String.duplicate("-", 30))
    ]

    assert {:ok, [record]} =
             MaryMartinDocx.segment(paragraphs, "vendor.docx")

    assert Enum.map(record.raw, & &1.text) == ["Title"]

    assert record.locator == %{
             paragraph_start: 2,
             paragraph_end: 2
           }
  end

  test "does not include Heading1 paragraphs in raw offer data" do
    paragraphs = [
      p(1, "History", "Heading1"),
      p(2, "Book title"),
      p(3, String.duplicate("-", 30))
    ]

    assert {:ok, [record]} =
             MaryMartinDocx.segment(paragraphs, "vendor.docx")

    refute Enum.any?(
             record.raw,
             &(&1.style == "Heading1")
           )
  end

  defp p(index, text, style \\ nil) do
    %Paragraph{
      index: index,
      text: text,
      style: style
    }
  end
end
