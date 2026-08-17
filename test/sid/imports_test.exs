defmodule Sid.ImportsTest do
  use ExUnit.Case, async: true

  alias Sid.Imports
  alias Sid.Imports.Identifier
  alias Sid.Imports.Parsers.VietnameseBooks
  alias Sid.Imports.SourceRecord
  alias Sid.Imports.TextContent

  test "processes a source record through parser and validator" do
    source =
      source_record(%{
        "Code" => "5032026",
        "Title" => "Cuba - Đi Lạc Trong Vòng Tay Thân Ái",
        "Title (TRANSLATION)" => "Cuba - Lost in Loving Arms",
        "ISBN" => "9786326041613",
        "Price in EUR" => Decimal.new("38.159999999999997")
      })

    assert {:ok, offer} =
             Imports.process(
               source,
               VietnameseBooks
             )

    assert offer.vendor_code == "5032026"

    assert [
             %TextContent{
               role: :primary_title,
               text: "Cuba - Đi Lạc Trong Vòng Tay Thân Ái"
             },
             %TextContent{
               role: :translated_title,
               text: "Cuba - Lost in Loving Arms"
             }
           ] = offer.titles

    assert [
             %Identifier{
               scheme: :isbn,
               value: "9786326041613",
               validation_status: :valid
             }
           ] = offer.identifiers

    assert Decimal.equal?(
             offer.price_amount,
             Decimal.new("38.16")
           )

    assert offer.source == source
  end

  test "preserves invalid ISBN values while marking them invalid" do
    source =
      source_record(%{
        "Title" => "Example title",
        "ISBN" => "9786041-27798"
      })

    assert {:ok, offer} =
             Imports.process(
               source,
               VietnameseBooks
             )

    assert [
             %Identifier{
               value: "9786041-27798",
               validation_status: :invalid
             }
           ] = offer.identifiers

    assert offer.source.raw["ISBN"] == "9786041-27798"
  end

  test "process_many preserves successful offers and reports failed records" do
    good =
      source_record(%{
        "Title" => "Một cuốn sách",
        "ISBN" => "9786326041613"
      })

    bad = %SourceRecord{
      format: :xlsx,
      source_filename: "vendor.xlsx",
      raw: "not a spreadsheet row"
    }

    assert {[offer], [{^bad, {:parse_error, :invalid_raw_record}}]} =
             Imports.process_many(
               [good, bad],
               VietnameseBooks
             )

    assert [%Identifier{validation_status: :valid}] =
             offer.identifiers
  end

  test "process_many preserves source order" do
    first =
      source_record(%{
        "Code" => "001",
        "Title" => "First"
      })

    second =
      source_record(%{
        "Code" => "002",
        "Title" => "Second"
      })

    assert {[first_offer, second_offer], []} =
             Imports.process_many(
               [first, second],
               VietnameseBooks
             )

    assert first_offer.vendor_code == "001"
    assert second_offer.vendor_code == "002"
  end

  defp source_record(raw) do
    %SourceRecord{
      format: :xlsx,
      source_filename: "vendor.xlsx",
      vendor: "Vietnamese Books Vendor",
      locator: %{sheet: "Sheet1", row: 4},
      raw: raw
    }
  end
end
