defmodule Sid.Imports.Interpretation.Result do
  @moduledoc """
  Result of semantic interpretation of source material that could not be
  classified deterministically.

  Values must remain grounded in the supplied source text. An interpreter may
  classify ambiguous source material, but must not invent, normalize, enrich,
  or correct it.
  """

  @enforce_keys [:source_lines]

  defstruct [
    :source_lines,
    :title,
    :responsibility_statement,
    vendor_classifications: [],
    descriptions: [],
    notes: [],
    unresolved: []
  ]

  @type t :: %__MODULE__{
          source_lines: [String.t()],
          title: String.t() | nil,
          responsibility_statement: String.t() | nil,
          vendor_classifications: [String.t()],
          descriptions: [String.t()],
          notes: [String.t()],
          unresolved: [String.t()]
        }
end
