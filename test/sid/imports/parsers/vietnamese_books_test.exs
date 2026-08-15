defmodule Sid.Imports.Parsers.VietnameseBooksTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.{
    Identifier,
    SourceRecord,
    TextContent
  }

  alias Sid.Imports.Parsers.VietnameseBooks

  test "parses a structured spreadsheet row deterministically" do
    raw = %{
      "Code" => "6012026",
      "Title" => "Kết quả tổng điều tra",
      "Title (TRANSLATION)" => "Results of the General Census",
      "ISBN" => "9786047957927",
      "Authors" => "Bộ Tài chính",
      "Content " => "Nội dung mô tả của nhà cung cấp.",
      "Publisher" => "Thống kê",
      "Year" => 2026,
      "Language" => "Vietnamese",
      "Size" => "20,5 x 29",
      "Pages" => 235,
      "Price in EUR" => 100
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert offer.vendor_code == "6012026"

    assert [
             %TextContent{
               role: :primary_title,
               text: "Kết quả tổng điều tra"
             },
             %TextContent{
               role: :translated_title,
               text: "Results of the General Census"
             }
           ] = offer.titles

    assert [
             %TextContent{
               role: :description,
               text: "Nội dung mô tả của nhà cung cấp."
             }
           ] = offer.descriptions

    assert offer.responsibility_statement == "Bộ Tài chính"
    assert offer.publication_statement == "Thống kê, 2026"
    assert offer.physical_description == "Pages: 235; Size: 20,5 x 29"
    assert offer.language_statements == ["Vietnamese"]

    assert [
             %Identifier{
               scheme: :isbn,
               value: "9786047957927",
               validation_status: :unchecked
             }
           ] = offer.identifiers

    assert Decimal.equal?(offer.price_amount, Decimal.new("100"))
    assert offer.price_currency == "EUR"
  end

  test "preserves the complete source row including unknown columns" do
    raw = %{
      "Code" => "6012026",
      "Title" => "Một cuốn sách",
      "Unknown Vendor Column" => "do not discard this"
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert offer.source.raw == raw

    assert offer.source.raw["Unknown Vendor Column"] ==
             "do not discard this"
  end

  test "accepts the observed content header with trailing whitespace" do
    raw = %{
      "Title" => "Một cuốn sách",
      "Content " => "Vendor description"
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert [%TextContent{text: "Vendor description"}] =
             offer.descriptions
  end

  test "falls back to the content header without trailing whitespace" do
    raw = %{
      "Title" => "Một cuốn sách",
      "Content" => "Vendor description"
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert [%TextContent{text: "Vendor description"}] =
             offer.descriptions
  end

  test "preserves unusual pagination instead of forcing it into an integer" do
    raw = %{
      "Title" => "Multi-volume publication",
      "Pages" => "over 3000"
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert offer.physical_description == "Pages: over 3000"
  end

  test "preserves malformed ISBN values without rejecting the offer" do
    raw = %{
      "Title" => "Example title",
      "ISBN" => "9786041-27798"
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert [
             %Identifier{
               scheme: :isbn,
               value: "9786041-27798",
               validation_status: :unchecked
             }
           ] = offer.identifiers
  end

  test "does not invent optional values that are absent from the source" do
    raw = %{
      "Title" => "Minimal record"
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert offer.vendor_code == nil
    assert offer.descriptions == []
    assert offer.identifiers == []
    assert offer.responsibility_statement == nil
    assert offer.publication_statement == nil
    assert offer.physical_description == nil
    assert offer.language_statements == []
    assert offer.price_amount == nil
    assert offer.price_currency == nil
  end

  test "preserves Unicode exactly" do
    title =
      "Tiếng Việt: Ấn phẩm nghiên cứu về Nguyễn Trãi và văn hóa Việt Nam"

    description =
      "Mô tả có đầy đủ dấu: ă â ê ô ơ ư đ á à ả ã ạ ấ ầ ẩ ẫ ậ."

    raw = %{
      "Title" => title,
      "Content " => description
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert [%TextContent{text: ^title}] = offer.titles
    assert [%TextContent{text: ^description}] = offer.descriptions
  end

  test "rejects source records whose raw representation is not a row map" do
    source = %SourceRecord{
      format: :xlsx,
      source_filename: "vendor-list.xlsx",
      raw: "not a spreadsheet row"
    }

    assert {:error, :invalid_raw_record} =
             VietnameseBooks.parse(source)
  end

  defp source_record(raw) do
    %SourceRecord{
      format: :xlsx,
      source_filename: "Buecherliste-2026.xlsx",
      vendor: "Vietnamese Books Vendor",
      locator: %{sheet: "Sheet1", row: 7},
      raw: raw
    }
  end

  test "converts spreadsheet float prices to two-decimal Decimal values" do
    raw = %{
      "Title" => "Example title",
      "Price in EUR" => 38.159999999999997
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert Decimal.equal?(
             offer.price_amount,
             Decimal.new("38.16")
           )

    assert offer.price_currency == "EUR"
  end

  test "rounds Decimal spreadsheet prices to two decimal places" do
    raw = %{
      "Title" => "Example title",
      "Price in EUR" => Decimal.new("38.159999999999997")
    }

    assert {:ok, offer} =
             raw
             |> source_record()
             |> VietnameseBooks.parse()

    assert Decimal.equal?(
             offer.price_amount,
             Decimal.new("38.16")
           )

    # The vendor source remains unchanged.
    assert Decimal.equal?(
             offer.source.raw["Price in EUR"],
             Decimal.new("38.159999999999997")
           )
  end
end
