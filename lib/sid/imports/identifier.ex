defmodule Sid.Imports.Identifier do
  @moduledoc """
  Represents an identifier supplied by or extracted from a vendor source.

  SID preserves the original identifier value even when validation fails.

  This is important because malformed or unusual vendor data must remain
  inspectable rather than disappearing during import.

  `scheme` may contain values such as `:isbn` or `:issn`.

  `validation_status` describes SID's knowledge of the identifier and must not
  be confused with whether the source supplied the value.
  """

  @enforce_keys [:scheme, :value]

  defstruct [
    :scheme,
    :value,
    validation_status: :unchecked,
    metadata: %{}
  ]

  @type validation_status ::
          :unchecked
          | :valid
          | :invalid
          | :uncertain

  @type t :: %__MODULE__{
          scheme: atom(),
          value: String.t(),
          validation_status: validation_status(),
          metadata: map()
        }
end
