defmodule Sid.Catalog.Record do
  @moduledoc """
  Represents a catalogue record returned to SID by a catalogue adapter.

  This struct is SID's internal representation and must not mirror the raw
  response format of any particular external catalogue API.

  Adapter implementations are responsible for translating external records
  into this representation.

  The structure is intentionally minimal during the MVP. Additional
  bibliographic fields should only be introduced after representative
  catalogue APIs and vendor data have been examined.
  """

  @enforce_keys [:source, :record_id]

  defstruct [
    :source,
    :record_id,
    :title,
    :creator,
    :isbn
  ]

  @type t :: %__MODULE__{
          source: String.t(),
          record_id: String.t(),
          title: String.t() | nil,
          creator: String.t() | nil,
          isbn: String.t() | nil
        }
end
