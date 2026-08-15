defmodule Sid.Imports.Extractors.XlsxTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Extractors.Xlsx
  alias Sid.Imports.SourceRecord

  describe "from_rows/4" do
    test "creates one source record per non-empty spreadsheet row" do
      rows = [
        [
          "Code",
          "Title",
          "ISBN",
          "Price in EUR"
        ],
        [
          "6012026",
          "Kết quả tổng điều tra",
          "9786047957927",
          Decimal.new("100")
        ],
        [
          "6022026",
          "Một cuốn sách khác",
          nil,
          Decimal.new("45.60")
        ]
      ]

      assert {:ok, records} =
               Xlsx.from_rows(
                 rows,
                 "Buecherliste-2026.xlsx",
                 "Sheet1",
                 vendor: "Vietnamese Books Vendor"
               )

      assert length(records) == 2

      assert [
               %SourceRecord{} = first,
               %SourceRecord{} = second
             ] = records

      assert first.format == :xlsx
      assert first.source_filename == "Buecherliste-2026.xlsx"
      assert first.vendor == "Vietnamese Books Vendor"

      assert first.locator == %{
               sheet: "Sheet1",
               row: 2
             }

      assert first.raw["Code"] == "6012026"
      assert first.raw["Title"] == "Kết quả tổng điều tra"
      assert first.raw["ISBN"] == "9786047957927"

      assert Decimal.equal?(
               first.raw["Price in EUR"],
               Decimal.new("100")
             )

      assert second.locator.row == 3
    end

    test "preserves header whitespace exactly" do
      rows = [
        [
          "Title",
          "Content",
          "Content "
        ],
        [
          "Một cuốn sách",
          "First value",
          "Second value"
        ]
      ]

      assert {:ok, [record]} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1"
               )

      assert record.raw["Content"] == "First value"
      assert record.raw["Content "] == "Second value"

      assert Map.has_key?(record.raw, "Content")
      assert Map.has_key?(record.raw, "Content ")
    end

    test "preserves unknown vendor columns" do
      rows = [
        [
          "Title",
          "Mystery Column"
        ],
        [
          "Example title",
          "Vendor-specific information"
        ]
      ]

      assert {:ok, [record]} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1"
               )

      assert record.raw["Mystery Column"] ==
               "Vendor-specific information"
    end

    test "retains empty header columns using deterministic internal names" do
      rows = [
        [
          "Title",
          nil,
          "Price"
        ],
        [
          "Example title",
          "Unlabelled source value",
          Decimal.new("20")
        ]
      ]

      assert {:ok, [record]} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1"
               )

      assert record.raw["__unnamed_column_2"] ==
               "Unlabelled source value"

      assert record.metadata.original_headers == [
               "Title",
               nil,
               "Price"
             ]
    end

    test "rejects exact duplicate headers instead of silently losing data" do
      rows = [
        [
          "Title",
          "ISBN",
          "ISBN"
        ],
        [
          "Example title",
          "9780000000001",
          "9780000000002"
        ]
      ]

      assert {:error, {:duplicate_headers, ["ISBN"]}} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1"
               )
    end

    test "fills missing trailing cells with nil" do
      rows = [
        [
          "Title",
          "ISBN",
          "Price"
        ],
        [
          "Example title"
        ]
      ]

      assert {:ok, [record]} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1"
               )

      assert record.raw == %{
               "Title" => "Example title",
               "ISBN" => nil,
               "Price" => nil
             }
    end

    test "skips completely empty rows" do
      rows = [
        ["Title"],
        [nil],
        [""],
        ["   "],
        ["Actual title"]
      ]

      assert {:ok, [record]} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1"
               )

      assert record.raw["Title"] == "Actual title"

      # The locator refers to the real worksheet row, including skipped rows.
      assert record.locator.row == 5
    end

    test "supports header rows that do not start on the first worksheet row" do
      rows = [
        ["Vendor price list 2026"],
        [],
        ["Code", "Title"],
        ["001", "Example title"]
      ]

      assert {:ok, [record]} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1",
                 header_row: 3
               )

      assert record.raw == %{
               "Code" => "001",
               "Title" => "Example title"
             }

      assert record.locator.row == 4
    end

    test "preserves complex Unicode without normalization" do
      title =
        "Pāṇini / Tiếng Việt / မြန်မာစာ / 中文 / 한국어 / हिन्दी / العربية / جاوي"

      rows = [
        ["Title"],
        [title]
      ]

      assert {:ok, [record]} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1"
               )

      assert record.raw["Title"] == title
    end

    test "rejects an invalid header row number" do
      assert {:error, {:invalid_header_row, 0}} =
               Xlsx.from_rows(
                 [],
                 "vendor.xlsx",
                 "Sheet1",
                 header_row: 0
               )
    end

    test "reports when the requested header row does not exist" do
      rows = [
        ["Title"]
      ]

      assert {:error, {:header_row_not_found, 3}} =
               Xlsx.from_rows(
                 rows,
                 "vendor.xlsx",
                 "Sheet1",
                 header_row: 3
               )
    end
  end
end
