defmodule Sid.Imports.Extractors.Docx.Paragraph do
  @moduledoc """
  Represents one paragraph extracted from a DOCX document.

  The structure deliberately contains only document-level information.
  It does not assign bibliographic meaning to the paragraph.

  `index` is one-based and refers to the paragraph's position in the DOCX
  document body.

  `style` contains the Word paragraph style identifier when present, such as
  `"Heading1"` or `"ListParagraph"`.

  `text` contains the complete visible paragraph text assembled from all text
  runs and hyperlinks belonging to the paragraph.
  """

  @enforce_keys [:index, :text]

  defstruct [
    :index,
    :text,
    :style
  ]

  @type t :: %__MODULE__{
          index: pos_integer(),
          text: String.t(),
          style: String.t() | nil
        }
end
