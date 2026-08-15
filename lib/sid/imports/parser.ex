defmodule Sid.Imports.Parser do
  @moduledoc """
  Behaviour implemented by vendor-format parsers.

  A parser receives a `Sid.Imports.SourceRecord` produced by a file-format
  extractor and returns a canonical `Sid.Imports.ExtractedOffer`.

  Parsers are responsible for deterministic interpretation of vendor-specific
  source structure.

  They must not:

  - read files directly;
  - perform catalogue lookups;
  - make acquisition decisions;
  - discard source data;
  - silently invent missing values.

  File extraction, parsing, validation, normalization, catalogue matching, and
  acquisition decisions remain separate processing stages.
  """

  alias Sid.Imports.{ExtractedOffer, SourceRecord}

  @callback parse(SourceRecord.t()) ::
              {:ok, ExtractedOffer.t()}
              | {:error, term()}
end
