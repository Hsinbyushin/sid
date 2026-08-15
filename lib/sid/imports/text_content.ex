defmodule Sid.Imports.TextContent do
  @moduledoc """
  Represents a textual value extracted from a vendor offer.

  The structure supports multiple textual representations without assuming that
  every publication has exactly one title or exactly one description.

  `role` describes the function of the text rather than its writing system.

  Expected roles currently include:

  - `:primary_title`
  - `:translated_title`
  - `:alternative_title`
  - `:description`

  `language` is optional because vendor data may not identify the language
  reliably. SID must not invent a language merely to satisfy the structure.

  The original text is preserved exactly as extracted. Unicode normalization,
  transliteration, and other matching-oriented transformations belong to later
  processing stages.
  """

  @enforce_keys [:role, :text]

  defstruct [
    :role,
    :text,
    :language,
    metadata: %{}
  ]

  @type role ::
          :primary_title
          | :translated_title
          | :alternative_title
          | :description
          | atom()

  @type t :: %__MODULE__{
          role: role(),
          text: String.t(),
          language: String.t() | nil,
          metadata: map()
        }
end
