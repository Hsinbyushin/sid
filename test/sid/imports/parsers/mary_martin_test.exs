defmodule Sid.Imports.Parsers.MaryMartinTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Extractors.Docx.Paragraph
  alias Sid.Imports.Parsers.MaryMartin
  alias Sid.Imports.SourceRecord
  alias Sid.Imports.TextContent

  test "parses a representative Brunei offer deterministically" do
    source =
      source_record(
        [
          p(12, "Kekreatifan Bahasa Iklan / Zurinah Ya’akub"),
          p(
            13,
            "Bandar Seri Begawan: Dewan Bahasa dan Pustaka Brunei, 2025"
          ),
          p(14, "xii, 74p."),
          p(15, "Includes Bibliography"),
          p(16, "9789998400962"),
          p(17, "Advertising – Language.", "ListParagraph"),
          p(18, "Advertising copy.", "ListParagraph"),
          p(
            19,
            "Language and languages in advertising.",
            "ListParagraph"
          ),
          p(20, "$ 25.00 / PB"),
          p(21, "148gm."),
          p(22, ""),
          p(
            23,
            "Hakikat tentang slogan iklan merupakan mesej ringkas dan kuat yang dirancang untuk menarik perhatian serta mencipta ingatan mendalam tentang sesuatu produk atau perkhidmatan."
          ),
          p(
            24,
            "http://www.marymartin.com/web?pid=908614"
          )
        ],
        "Communication/Journalism"
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert [
             %TextContent{
               role: :primary_title,
               text: "Kekreatifan Bahasa Iklan"
             }
           ] = offer.titles

    assert offer.responsibility_statement ==
             "Zurinah Ya’akub"

    assert offer.publication_statement ==
             "Bandar Seri Begawan: Dewan Bahasa dan Pustaka Brunei, 2025"

    assert offer.physical_description ==
             "xii, 74p."

    assert offer.notes == [
             "Includes Bibliography"
           ]

    assert offer.subjects == [
             "Advertising – Language.",
             "Advertising copy.",
             "Language and languages in advertising."
           ]

    assert [
             identifier
           ] = offer.identifiers

    assert identifier.scheme == :isbn
    assert identifier.value == "9789998400962"
    assert identifier.validation_status == :unchecked

    assert Decimal.equal?(
             offer.price_amount,
             Decimal.new("25.00")
           )

    assert offer.price_currency == "$"
    assert offer.binding == "PB"
    assert offer.weight == "148gm."

    assert offer.vendor_url ==
             "http://www.marymartin.com/web?pid=908614"

    assert offer.vendor_category ==
             "Communication/Journalism"

    assert [
             %TextContent{
               role: :description,
               text: description
             }
           ] = offer.descriptions

    assert String.starts_with?(
             description,
             "Hakikat tentang slogan"
           )
  end

  test "parses short parenthesized vendor information as a note" do
    source =
      source_record(
        [
          p(
            28,
            "Menjejaki Sejarah Yang Dilupakan / Pengiran Haji Zainal Abidin"
          ),
          p(
            29,
            "Bandar Seri Begawan: Dewan Bahasa dan Pustaka Brunei, 2025"
          ),
          p(30, "xviii. 110p."),
          p(31, "Includes Bibliography"),
          p(32, "9789998400436"),
          p(35, "$ 35.00 / PB"),
          p(36, "392gm."),
          p(38, "(History/Biographical History)"),
          p(
            39,
            "http://www.marymartin.com/web?pid=908615"
          )
        ],
        "History"
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert "Includes Bibliography" in offer.notes

    assert "(History/Biographical History)" in offer.notes

    assert offer.descriptions == []
  end

  test "parses series statements before the publication statement" do
    source =
      source_record(
        [
          p(
            100,
            "Berjumpa Keluarga Andapung / Aisyah Az-Zahra’"
          ),
          p(101, "Bumbu Bacaan Series"),
          p(
            102,
            "Bandar Seri Begawan: Dewan Bahasa dan Pustaka Brunei, 2025"
          ),
          p(103, "vi, 54p. ; 22cm."),
          p(104, "9789998400986"),
          p(105, "Children’s stories, Malay.", "ListParagraph"),
          p(106, "$ 12.00 / PB"),
          p(107, "130gm."),
          p(
            108,
            "http://www.marymartin.com/web?pid=908626"
          )
        ],
        "Literature"
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert offer.series_statements == [
             "Bumbu Bacaan Series"
           ]
  end

  test "preserves explicitly supplied BND currency" do
    source =
      source_record(
        [
          p(
            200,
            "Perkhidmatan: Budi Pekerti, Tuturan Hati / Tengku Sri Indra"
          ),
          p(
            201,
            "Bandar Seri Begawan: Dewan Bahasa dan Pustaka Brunei, 2025"
          ),
          p(202, "x, 42p."),
          p(203, "9789998401037"),
          p(204, "Customer services – Management.", "ListParagraph"),
          p(205, "BND 8.00 / PB"),
          p(206, "104gm."),
          p(
            207,
            "http://www.marymartin.com/web?pid=908636"
          )
        ],
        "Sociology"
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert Decimal.equal?(
             offer.price_amount,
             Decimal.new("8.00")
           )

    assert offer.price_currency == "BND"
    assert offer.binding == "PB"
  end

  test "extracts the URL from hyperlink-like source text" do
    source =
      source_record(
        [
          p(1, "Example title / Example Author"),
          p(
            2,
            "Bandar Seri Begawan: Example Publisher, 2025"
          ),
          p(3, "100 p"),
          p(4, "$ 20.00 / PB"),
          p(
            5,
            "[http://www.marymartin.com/web?pid=123456](http://www.marymartin.com/web?pid=123456)"
          )
        ],
        "History"
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert offer.vendor_url ==
             "http://www.marymartin.com/web?pid=123456"
  end

  test "rejects the Mary Martin document preamble as not being an offer" do
    source =
      source_record(
        [
          p(
            1,
            "Recent Bruneian Books from Brunei – Sept 2025"
          ),
          p(3, "Mary Martin Booksellers Pte Ltd"),
          p(4, "Blk 231, Bain Street"),
          p(5, "#03-05, Bras Basah Complex"),
          p(6, "Singapore 180231"),
          p(7, "Tel : +65-6883-2284/6883-2204"),
          p(8, "info@marymartin.com"),
          p(9, "www.marymartin.com")
        ],
        nil
      )

    assert {:error, :not_offer} =
             MaryMartin.parse(source)
  end

  test "leaves unresolved source material in unparsed" do
    source =
      source_record(
        [
          p(1, "Example title / Example Author"),
          p(
            2,
            "Bandar Seri Begawan: Example Publisher, 2025"
          ),
          p(3, "100 p"),
          p(4, "Unexpected metadata statement"),
          p(5, "$ 20.00 / PB"),
          p(
            6,
            "http://www.marymartin.com/web?pid=123456"
          )
        ],
        "History"
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert offer.unparsed == [
             "Unexpected metadata statement"
           ]
  end

  defp source_record(paragraphs, category) do
    %SourceRecord{
      format: :docx,
      source_filename: "brunei.docx",
      vendor: "Mary Martin Booksellers",
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

  defp p(index, text, style \\ nil) do
    %Paragraph{
      index: index,
      text: text,
      style: style
    }
  end

  test "parses multiple logical lines stored inside one DOCX paragraph" do
    source =
      source_record(
        [
          p(
            12,
            "Festival Rambu Solo; Kematian dalam Kehormatan di Toraja/Heti Sorenda"
          ),
          p(
            13,
            "Indonesia : Histokultura 2025\n" <>
              "X+82 p\n" <>
              "Arts\n" <>
              "9786237554554\n" <>
              "USD : 12.40 / PB\n" <>
              "121 gm."
          ),
          p(
            14,
            "https://www.marymartin.com/web?pid=908034"
          )
        ],
        nil
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert offer.publication_statement ==
             "Indonesia : Histokultura 2025"

    assert offer.physical_description ==
             "X+82 p"

    assert [
             identifier
           ] = offer.identifiers

    assert identifier.value == "9786237554554"

    assert Decimal.equal?(
             offer.price_amount,
             Decimal.new("12.40")
           )

    assert offer.price_currency == "USD"
    assert offer.binding == "PB"
    assert offer.weight == "121 gm."

    assert offer.vendor_category == "Arts"
    assert offer.unparsed == []
  end

  test "prefers explicit DOCX category context over an inferred category" do
    source =
      source_record(
        [
          p(1, "Example title / Example Author"),
          p(
            2,
            "Indonesia : Example Publisher 2025\n" <>
              "100 p\n" <>
              "Arts\n" <>
              "9783161484100\n" <>
              "USD : 20.00 / PB\n" <>
              "200 gm."
          ),
          p(
            3,
            "https://www.marymartin.com/web?pid=123456"
          )
        ],
        "History"
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert offer.vendor_category == "History"
  end

  test "accepts an offer title without a responsibility separator" do
    source =
      source_record(
        [
          p(1, "Example title without responsibility"),
          p(
            2,
            "Indonesia : Example Publisher 2025\n" <>
              "100 p\n" <>
              "History\n" <>
              "9783161484100\n" <>
              "USD : 20.00 / PB\n" <>
              "200 gm."
          ),
          p(
            3,
            "https://www.marymartin.com/web?pid=123456"
          )
        ],
        nil
      )

    assert {:ok, offer} =
             MaryMartin.parse(source)

    assert [
             %TextContent{
               role: :primary_title,
               text: "Example title without responsibility"
             }
           ] = offer.titles

    assert offer.responsibility_statement == nil
  end

  test "removes Mary Martin preamble before the first offer" do
    source =
      source_record(
        [
          p(
            1,
            "Recent Bahasa Books from Indonesia - Sept 2025\n\n" <>
              "Mary Martin Booksellers Pte Ltd\n" <>
              "Blk 231, Bain Street\n" <>
              "#03-05, Bras Basah Complex\n" <>
              "Singapore 180231\n" <>
              "Tel : +65-6883-2284/6883-2204"
          ),
          p(2, "info@marymartin.com"),
          p(3, "www.marymartin.com"),
          p(
            4,
            "Menuju antropologi Islam : budaya lokal dan Islam/" <>
              "Nawari Ismail ; , Hanita Ayu"
          ),
          p(
            5,
            "Indonesia : Samudera Biru 2025\n" <>
              "180 p\n" <>
              "Anthropology/Archaeology\n" <>
              "9786232619203\n" <>
              "USD : 17.20 / PB\n" <>
              "250 gm."
          ),
          p(
            6,
            "https://www.marymartin.com/web?pid=908073"
          )
        ],
        nil
      )

    assert {:ok, offer} = MaryMartin.parse(source)

    assert hd(offer.titles).text ==
             "Menuju antropologi Islam : budaya lokal dan Islam"

    assert offer.responsibility_statement ==
             "Nawari Ismail ; , Hanita Ayu"

    assert offer.publication_statement ==
             "Indonesia : Samudera Biru 2025"

    assert Decimal.equal?(
             offer.price_amount,
             Decimal.new("17.20")
           )
  end

  test "rejects a preamble when no offer follows it" do
    source =
      source_record(
        [
          p(1, "Recent Bruneian Books from Brunei – Sept 2025"),
          p(2, "Mary Martin Booksellers Pte Ltd"),
          p(3, "Blk 231, Bain Street"),
          p(4, "www.marymartin.com")
        ],
        nil
      )

    assert {:error, :not_offer} =
             MaryMartin.parse(source)
  end
end
