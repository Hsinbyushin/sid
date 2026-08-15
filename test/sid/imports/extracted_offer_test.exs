defmodule Sid.Imports.ExtractedOfferTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.{
    ExtractedOffer,
    Identifier,
    SourceRecord,
    TextContent
  }

  test "preserves the complete original spreadsheet row" do
    raw_row = %{
      "Code" => "6012026",
      "Title" => "Kết quả tổng điều tra",
      "Content " => "Original vendor description",
      "Price in EUR" => "100",
      "Unknown Vendor Column" => "must not disappear"
    }

    source = %SourceRecord{
      format: :xlsx,
      source_filename: "Buecherliste-2026.xlsx",
      vendor: "Example Vendor",
      locator: %{sheet: "Sheet1", row: 7},
      raw: raw_row
    }

    offer = %ExtractedOffer{source: source}

    assert offer.source.raw == raw_row

    assert offer.source.raw["Unknown Vendor Column"] ==
             "must not disappear"
  end

  test "supports original and translated titles without conflating them" do
    source = source_record()

    offer = %ExtractedOffer{
      source: source,
      titles: [
        %TextContent{
          role: :primary_title,
          text: "Vọng Âm Sắc Màu",
          language: "vi"
        },
        %TextContent{
          role: :translated_title,
          text: "Colorful Echoes",
          language: "en"
        }
      ]
    }

    assert Enum.map(offer.titles, & &1.text) == [
             "Vọng Âm Sắc Màu",
             "Colorful Echoes"
           ]

    assert Enum.map(offer.titles, & &1.role) == [
             :primary_title,
             :translated_title
           ]
  end

  test "supports multiple descriptions in different languages" do
    offer = %ExtractedOffer{
      source: source_record(),
      descriptions: [
        %TextContent{
          role: :description,
          text: "Mô tả bằng tiếng Việt.",
          language: "vi"
        },
        %TextContent{
          role: :description,
          text: "Description in English.",
          language: "en"
        }
      ]
    }

    assert length(offer.descriptions) == 2

    assert Enum.any?(offer.descriptions, fn description ->
             description.language == "vi" and
               description.text == "Mô tả bằng tiếng Việt."
           end)

    assert Enum.any?(offer.descriptions, fn description ->
             description.language == "en" and
               description.text == "Description in English."
           end)
  end

  test "preserves malformed identifiers instead of discarding them" do
    identifier = %Identifier{
      scheme: :isbn,
      value: "9786041-27798",
      validation_status: :invalid
    }

    offer = %ExtractedOffer{
      source: source_record(),
      identifiers: [identifier]
    }

    assert [%Identifier{} = stored_identifier] = offer.identifiers
    assert stored_identifier.value == "9786041-27798"
    assert stored_identifier.validation_status == :invalid
  end

  test "supports multiple identifiers for multi-volume publications" do
    offer = %ExtractedOffer{
      source: source_record(),
      identifiers: [
        %Identifier{
          scheme: :isbn,
          value: "9789719094425",
          metadata: %{volume: "1"}
        },
        %Identifier{
          scheme: :isbn,
          value: "9789719094432",
          metadata: %{volume: "2"}
        }
      ]
    }

    assert length(offer.identifiers) == 2

    assert Enum.map(offer.identifiers, & &1.value) == [
             "9789719094425",
             "9789719094432"
           ]
  end

  test "keeps commercial offer data separate from bibliographic statements" do
    offer = %ExtractedOffer{
      source: source_record(),
      publication_statement: "Penang: Example University Press, 2026",
      price_amount: Decimal.new("19.00"),
      price_currency: "USD",
      binding: "PB",
      weight: "244gm."
    }

    assert offer.publication_statement ==
             "Penang: Example University Press, 2026"

    assert Decimal.equal?(offer.price_amount, Decimal.new("19.00"))
    assert offer.price_currency == "USD"
    assert offer.binding == "PB"
    assert offer.weight == "244gm."
  end

  test "preserves unclassified source material for later inspection" do
    offer = %ExtractedOffer{
      source: source_record(),
      unparsed: [
        "Unexpected bibliographic line",
        "Another value that cannot yet be classified"
      ]
    }

    assert offer.unparsed == [
             "Unexpected bibliographic line",
             "Another value that cannot yet be classified"
           ]
  end

  test "preserves complex Unicode exactly" do
    title =
      "Pāṇini / Tiếng Việt / မြန်မာစာ / 中文 / 한국어 / हिन्दी / العربية / جاوي / ᠮᠣᠩᠭᠣᠯ"

    offer = %ExtractedOffer{
      source: source_record(),
      titles: [
        %TextContent{
          role: :primary_title,
          text: title
        }
      ]
    }

    assert [%TextContent{text: ^title}] = offer.titles
  end

  defp source_record do
    %SourceRecord{
      format: :pdf,
      source_filename: "vendor-list.pdf",
      vendor: "Example Vendor",
      locator: %{page: 1, block: 1},
      raw: "Original source fragment"
    }
  end
end
