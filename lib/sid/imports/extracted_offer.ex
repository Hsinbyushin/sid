defmodule Sid.Imports.ExtractedOffer do
  @moduledoc """
  Canonical result produced by a deterministic vendor-format parser.

  `ExtractedOffer` is deliberately not an authoritative bibliographic record.

  It represents SID's structured extraction of one vendor offer while keeping
  the original `SourceRecord` available for provenance and later review.

  Fields remain close to what can be justified from the source material.
  Ambiguous source statements should remain in their original statement fields
  rather than being over-interpreted.

  For example, a parser may safely extract a complete responsibility statement
  without yet determining every contributor and contributor role.

  Likewise, a complex physical description may remain a source statement even
  when parts of it cannot yet be normalized reliably.
  """

  alias Sid.Imports.{Identifier, SourceRecord, TextContent}

  @enforce_keys [:source]

  defstruct [
    :source,

    # Vendor-specific commercial information.
    :vendor_code,
    :vendor_url,

    # Repeatable textual content.
    titles: [],
    descriptions: [],

    # Statements retained when further semantic decomposition would be unsafe.
    responsibility_statement: nil,
    publication_statement: nil,
    physical_description: nil,
    edition_statement: nil,

    # Repeatable bibliographic/vendor metadata.
    identifiers: [],
    language_statements: [],
    series_statements: [],
    subjects: [],
    notes: [],

    # Vendor classification is deliberately separate from bibliographic subjects.
    vendor_category: nil,

    # Commercial offer information.
    price_amount: nil,
    price_currency: nil,
    price_qualifier: nil,
    binding: nil,
    weight: nil,

    # Source material that could not yet be classified safely.
    unparsed: [],

    # Non-fatal parser observations requiring later inspection.
    warnings: [],

    # Parser-specific provenance and diagnostics that do not belong to the
    # bibliographic or commercial data itself.
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          source: SourceRecord.t(),
          vendor_code: String.t() | nil,
          vendor_url: String.t() | nil,
          titles: [TextContent.t()],
          descriptions: [TextContent.t()],
          responsibility_statement: String.t() | nil,
          publication_statement: String.t() | nil,
          physical_description: String.t() | nil,
          edition_statement: String.t() | nil,
          identifiers: [Identifier.t()],
          language_statements: [String.t()],
          series_statements: [String.t()],
          subjects: [String.t()],
          notes: [String.t()],
          vendor_category: String.t() | nil,
          price_amount: Decimal.t() | nil,
          price_currency: String.t() | nil,
          price_qualifier: String.t() | nil,
          binding: String.t() | nil,
          weight: String.t() | nil,
          unparsed: [term()],
          warnings: [term()],
          metadata: map()
        }
end
