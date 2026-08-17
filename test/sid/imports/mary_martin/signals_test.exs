defmodule Sid.Imports.MaryMartin.SignalsTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.MaryMartin.Signals

  test "parses a USD price statement" do
    assert {:ok, price} =
             Signals.parse_price("USD : 45.00 / PB")

    assert Decimal.equal?(
             price.amount,
             Decimal.new("45.00")
           )

    assert price.currency == "USD"
    assert price.binding == "PB"
    assert price.qualifier == nil
  end

  test "parses a BND price statement" do
    assert {:ok, price} =
             Signals.parse_price("BND 8.00 / PB")

    assert Decimal.equal?(
             price.amount,
             Decimal.new("8.00")
           )

    assert price.currency == "BND"
  end

  test "does not mistake an isolated zero for a price" do
    assert :error = Signals.parse_price("0")
    refute Signals.price?("0")
  end

  test "recognizes an ISBN candidate" do
    assert {:ok, identifier} =
             Signals.identifier_candidate("9786237554554")

    assert identifier.scheme == :isbn
    assert identifier.value == "9786237554554"
  end

  test "accepts ISBN candidates containing separators" do
    assert {:ok, identifier} =
             Signals.identifier_candidate("978-623-7554-55-4")

    assert identifier.scheme == :isbn
    assert identifier.value == "978-623-7554-55-4"
  end

  test "does not mistake an isolated zero for an identifier" do
    assert :error =
             Signals.identifier_candidate("0")
  end

  test "does not validate the ISBN checksum at signal detection time" do
    assert {:ok, identifier} =
             Signals.identifier_candidate("7661303251963")

    assert identifier.value == "7661303251963"
  end

  test "recognizes physical descriptions" do
    assert Signals.physical_description?("396 p")
    assert Signals.physical_description?("xii, 74p.")
    assert Signals.physical_description?("xxii, 116p. ; 23cm.")
    assert Signals.physical_description?("10 v.")
  end

  test "recognizes Indonesian compact physical descriptions" do
    assert Signals.physical_description?("X+82 p")
    assert Signals.physical_description?("VIII+98 p")
  end

  test "does not mistake unrelated numeric material for a physical description" do
    refute Signals.physical_description?("0")
    refute Signals.physical_description?("9786237554554")
    refute Signals.physical_description?("921 gm.")
    refute Signals.physical_description?("USD : 45.00 / PB")
  end

  test "recognizes publication statements" do
    assert Signals.publication_statement?("Indonesia : Histokultura 2025")

    assert Signals.publication_statement?(
             "Indonesia : Dinas Kependudukan dan Pencatatan Sipil, Provinsi DKI Jakarta 2024"
           )

    assert Signals.publication_statement?(
             "Bandar Seri Begawan: Dewan Bahasa dan Pustaka Brunei, 2025"
           )
  end

  test "does not mistake other source material for a publication statement" do
    refute Signals.publication_statement?("396 p")
    refute Signals.publication_statement?("Sociology/Culture Studies")
    refute Signals.publication_statement?("0")
    refute Signals.publication_statement?("9786237554554")
    refute Signals.publication_statement?("USD : 45.00 / PB")
  end

  test "recognizes weight statements" do
    assert Signals.weight?("121 gm.")
    assert Signals.weight?("921 gm.")
    assert Signals.weight?("1.2 kg")
    assert Signals.weight?("1,5 kg.")
  end

  test "does not mistake unrelated numeric material for weight" do
    refute Signals.weight?("0")
    refute Signals.weight?("396 p")
    refute Signals.weight?("9786237554554")
    refute Signals.weight?("USD : 45.00 / PB")
  end

  test "extracts a Mary Martin vendor URL" do
    assert {:ok, url} =
             Signals.vendor_url("https://www.marymartin.com/web?pid=908034")

    assert url ==
             "https://www.marymartin.com/web?pid=908034"
  end

  test "extracts a Mary Martin URL from surrounding source text" do
    assert {:ok, url} =
             Signals.vendor_url(
               "[https://www.marymartin.com/web?pid=908034](https://www.marymartin.com/web?pid=908034)"
             )

    assert url ==
             "https://www.marymartin.com/web?pid=908034"
  end

  test "rejects unrelated URLs as Mary Martin vendor URLs" do
    assert :error =
             Signals.vendor_url("https://example.com/book/123")

    refute Signals.vendor_url?("https://example.com/book/123")
  end
end
