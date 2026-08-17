defmodule Sid.Imports.Interpretation.Input do
  @moduledoc """
  Input prepared for semantic interpretation.

  Deterministically recognized source material is kept separate from the
  source lines that still require semantic interpretation.
  """

  @enforce_keys [:source_lines, :remaining_lines]

  defstruct [
    :source_lines,
    :remaining_lines,
    deterministic: %{}
  ]

  @type t :: %__MODULE__{
          source_lines: [String.t()],
          remaining_lines: [String.t()],
          deterministic: map()
        }
end
