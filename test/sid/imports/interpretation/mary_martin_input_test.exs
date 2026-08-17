defmodule Sid.Imports.Interpretation.MaryMartinInputTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Extractors.Docx.Paragraph
  alias Sid.Imports.Interpretation.MaryMartinInput
  alias Sid.Imports.SourceRecord

  test "separates deterministic values from material requiring interpretation" do
    source =
      source_record([
        p(
          1,
          "Profil perkembangan kependudukan Provinsi DKI Jakarta tahun 2023./Dinas Kependudukan dan Pencatatan Sipil, Provinsi DKI Jakarta"
        ),
        p(
          2,
          """
          Indonesia : Dinas Kependudukan dan Pencatatan Sipil, Provinsi DKI Jakarta 2024
          396 p
          Sociology/Culture Studies
          0
          USD : 45.00 / PB
          921 gm.
          """
        ),
        p(
          3,
          "https://www.marymartin.com/web?pid=256133"
        ),
        p(4, "শিমুলজাবালি")
      ])

    input = MaryMartinInput.prepare(source)

    assert input.deterministic.weight == "921 gm."

    assert input.deterministic.vendor_url ==
             "https://www.marymartin.com/web?pid=256133"

    assert "Sociology/Culture Studies" in input.remaining_lines
    assert "0" in input.remaining_lines
    assert "শিমুলজাবালি" in input.remaining_lines

    refute "396 p" in input.remaining_lines
    assert input.deterministic.physical_description == "396 p"
    refute "USD : 45.00 / PB" in input.remaining_lines

    assert input.deterministic.price_source ==
             "USD : 45.00 / PB"

    assert Decimal.equal?(
             input.deterministic.price_amount,
             Decimal.new("45.00")
           )

    assert input.deterministic.price_currency == "USD"
    assert input.deterministic.binding == "PB"

    refute "Indonesia : Dinas Kependudukan dan Pencatatan Sipil, Provinsi DKI Jakarta 2024" in input.remaining_lines

    assert input.deterministic.publication_statement ==
             "Indonesia : Dinas Kependudukan dan Pencatatan Sipil, Provinsi DKI Jakarta 2024"
  end

  test "removes identifier candidates from material requiring interpretation" do
    source =
      source_record([
        p(1, "Festival Rambu Solo / Heti Sorenda"),
        p(2, "9786237554554"),
        p(3, "0")
      ])

    input = MaryMartinInput.prepare(source)

    assert input.deterministic.identifiers == [
             %{
               scheme: :isbn,
               value: "9786237554554"
             }
           ]

    refute "9786237554554" in input.remaining_lines
    assert "0" in input.remaining_lines

    assert "Festival Rambu Solo / Heti Sorenda" in input.remaining_lines
  end

  defp source_record(paragraphs) do
    %SourceRecord{
      format: :docx,
      source_filename: "indonesia.docx",
      vendor: "Mary Martin Booksellers",
      locator: %{},
      raw: paragraphs,
      metadata: %{}
    }
  end

  defp p(index, text) do
    %Paragraph{
      index: index,
      text: text
    }
  end
end
