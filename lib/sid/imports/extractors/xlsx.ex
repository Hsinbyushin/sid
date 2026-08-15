defmodule Sid.Imports.Extractors.Xlsx do
  @moduledoc """
  Extracts spreadsheet rows from XLSX files into `SourceRecord` structs.

  This module is intentionally vendor-neutral.

  It knows how to:

  - open an XLSX workbook;
  - read worksheets;
  - interpret one row as a header row;
  - associate subsequent cells with those headers;
  - preserve the original worksheet location;
  - skip completely empty rows.

  It does not know what fields such as "Title", "ISBN", or "Price in EUR"
  mean. Vendor-specific interpretation belongs to a parser such as
  `Sid.Imports.Parsers.VietnameseBooks`.

  Header text is preserved exactly. In particular, the extractor does not
  trim headers because vendor files may contain technically distinct columns
  such as "Content" and "Content ".

  Empty headers receive deterministic internal column names so that their
  values are not silently discarded. The complete original header row is also
  retained in source metadata.

  Exact duplicate non-empty headers are rejected because converting them
  silently to a map would otherwise destroy data.
  """

  alias Sid.Imports.SourceRecord

  @type extract_option ::
          {:vendor, String.t()}
          | {:sheet, String.t()}
          | {:header_row, pos_integer()}

  @spec extract(Path.t(), [extract_option()]) ::
          {:ok, [SourceRecord.t()]} | {:error, term()}
  def extract(path, opts \\ []) when is_binary(path) do
    vendor = Keyword.get(opts, :vendor)
    requested_sheet = Keyword.get(opts, :sheet)
    header_row = Keyword.get(opts, :header_row, 1)

    with :ok <- validate_header_row(header_row),
         {:ok, package} <- XlsxReader.open(path),
         {:ok, sheet_names} <- selected_sheet_names(package, requested_sheet),
         {:ok, records} <-
           extract_sheets(
             package,
             sheet_names,
             path,
             vendor,
             header_row
           ) do
      {:ok, records}
    end
  end

  @doc """
  Converts already extracted worksheet rows into `SourceRecord` structs.

  This function exists primarily to keep row interpretation independent from
  the XLSX library itself and to make the source-record logic easy to test.

  Row numbers are one-based and refer to their position in the worksheet.
  """
  @spec from_rows(
          [[term()]],
          String.t(),
          String.t(),
          keyword()
        ) ::
          {:ok, [SourceRecord.t()]} | {:error, term()}
  def from_rows(rows, source_filename, sheet_name, opts \\ [])
      when is_list(rows) do
    vendor = Keyword.get(opts, :vendor)
    header_row = Keyword.get(opts, :header_row, 1)

    with :ok <- validate_header_row(header_row),
         {:ok, headers, data_rows} <- split_header(rows, header_row),
         {:ok, mapped_headers} <- prepare_headers(headers) do
      records =
        data_rows
        |> Enum.with_index(header_row + 1)
        |> Enum.reject(fn {row, _row_number} ->
          empty_row?(row)
        end)
        |> Enum.map(fn {row, row_number} ->
          raw =
            mapped_headers
            |> build_row_map(row)

          %SourceRecord{
            format: :xlsx,
            source_filename: source_filename,
            vendor: vendor,
            locator: %{
              sheet: sheet_name,
              row: row_number
            },
            raw: raw,
            metadata: %{
              original_headers: headers
            }
          }
        end)

      {:ok, records}
    end
  end

  defp extract_sheets(
         package,
         sheet_names,
         path,
         vendor,
         header_row
       ) do
    Enum.reduce_while(sheet_names, {:ok, []}, fn sheet_name, {:ok, acc} ->
      case XlsxReader.sheet(
             package,
             sheet_name,
             number_type: Decimal
           ) do
        {:ok, rows} ->
          case from_rows(
                 rows,
                 Path.basename(path),
                 sheet_name,
                 vendor: vendor,
                 header_row: header_row
               ) do
            {:ok, records} ->
              {:cont, {:ok, acc ++ records}}

            {:error, reason} ->
              {:halt, {:error, {:sheet_error, sheet_name, reason}}}
          end

        {:error, reason} ->
          {:halt, {:error, {:sheet_error, sheet_name, reason}}}
      end
    end)
  end

  defp selected_sheet_names(package, nil) do
    {:ok, XlsxReader.sheet_names(package)}
  end

  defp selected_sheet_names(package, requested_sheet) do
    sheet_names = XlsxReader.sheet_names(package)

    if requested_sheet in sheet_names do
      {:ok, [requested_sheet]}
    else
      {:error, {:sheet_not_found, requested_sheet}}
    end
  end

  defp split_header(rows, header_row) do
    case Enum.fetch(rows, header_row - 1) do
      {:ok, headers} ->
        data_rows =
          rows
          |> Enum.drop(header_row)

        {:ok, headers, data_rows}

      :error ->
        {:error, {:header_row_not_found, header_row}}
    end
  end

  defp prepare_headers(headers) do
    mapped_headers =
      headers
      |> Enum.with_index(1)
      |> Enum.map(fn {header, column_number} ->
        prepare_header(header, column_number)
      end)

    duplicates =
      mapped_headers
      |> Enum.reject(&unnamed_header?/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_header, count} -> count > 1 end)
      |> Enum.map(fn {header, _count} -> header end)

    case duplicates do
      [] ->
        {:ok, mapped_headers}

      duplicate_headers ->
        {:error, {:duplicate_headers, duplicate_headers}}
    end
  end

  defp prepare_header(nil, column_number) do
    unnamed_header(column_number)
  end

  defp prepare_header("", column_number) do
    unnamed_header(column_number)
  end

  defp prepare_header(header, column_number) when is_binary(header) do
    if String.trim(header) == "" do
      unnamed_header(column_number)
    else
      header
    end
  end

  defp prepare_header(header, _column_number) do
    to_string(header)
  end

  defp unnamed_header(column_number) do
    "__unnamed_column_#{column_number}"
  end

  defp unnamed_header?(header) do
    String.starts_with?(header, "__unnamed_column_")
  end

  defp build_row_map(headers, row) do
    padded_row =
      row
      |> pad_row(length(headers))

    headers
    |> Enum.zip(padded_row)
    |> Map.new()
  end

  defp pad_row(row, required_length) do
    missing_cells =
      max(required_length - length(row), 0)

    row ++ List.duplicate(nil, missing_cells)
  end

  defp empty_row?(row) do
    Enum.all?(row, &empty_cell?/1)
  end

  defp empty_cell?(nil), do: true

  defp empty_cell?(value) when is_binary(value) do
    String.trim(value) == ""
  end

  defp empty_cell?(_value), do: false

  defp validate_header_row(header_row)
       when is_integer(header_row) and header_row > 0,
       do: :ok

  defp validate_header_row(header_row),
    do: {:error, {:invalid_header_row, header_row}}
end
