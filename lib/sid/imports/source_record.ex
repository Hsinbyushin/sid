defmodule Sid.Imports.SourceRecord do
  @moduledoc """
  Represents one source fragment extracted from an imported vendor document.

  A source record is deliberately format-agnostic. Depending on the source
  document, its raw content may represent:

  - one spreadsheet row,
  - one DOCX record block,
  - one PDF record block,
  - or another future source representation.

  The original extracted content is preserved so that parsed values can always
  be traced back to what the vendor actually supplied.

  `locator` describes where the record came from without imposing one location
  model on every file format. Examples include:

      %{sheet: "Sheet1", row: 7}

      %{page: 3, block: 4}

      %{paragraph_start: 18, paragraph_end: 26}

  The structure is intentionally not persisted yet. It defines the contract
  between file-format extraction and vendor-specific parsing.
  """

  @enforce_keys [:format, :source_filename, :raw]

  defstruct [
    :format,
    :source_filename,
    :vendor,
    :raw,
    locator: %{},
    metadata: %{}
  ]

  @type format :: :xlsx | :xls | :csv | :docx | :pdf | atom()

  @type t :: %__MODULE__{
          format: format(),
          source_filename: String.t(),
          vendor: String.t() | nil,
          raw: term(),
          locator: map(),
          metadata: map()
        }
end
