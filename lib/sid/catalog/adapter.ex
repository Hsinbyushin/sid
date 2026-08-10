defmodule Sid.Catalog.Adapter do
  @moduledoc """
  Defines the contract between SID and an external library catalogue.

  Catalogue-specific implementations must conform to this behaviour so that
  the rest of SID does not depend on a particular catalogue API, protocol,
  vendor, or library system.

  Adapters are responsible for translating catalogue-specific responses into
  SID's internal catalogue result representation.

  This boundary is intentionally kept independent from the acquisition
  planning domain. Order plans, order lists, and future vendor imports should
  never need to know which catalogue system is being queried.
  """

  alias Sid.Catalog.Record

  @typedoc """
  A catalogue search query.

  The query is deliberately generic at this stage. More specialized search
  criteria can be introduced once the requirements of real catalogue APIs
  have been examined.
  """
  @type query :: String.t()

  @typedoc """
  A catalogue-specific record identifier.

  SID treats this identifier as opaque. Its structure and meaning belong to
  the catalogue adapter.
  """
  @type record_id :: String.t()

  @typedoc """
  An error returned by a catalogue adapter.

  The precise external error must not leak through the catalogue boundary.
  """
  @type reason ::
          :unavailable
          | :timeout
          | :unauthorized
          | :invalid_request
          | :not_found
          | {:unexpected, term()}

  @callback search(query()) ::
              {:ok, [Record.t()]}
              | {:error, reason()}

  @callback lookup(record_id()) ::
              {:ok, Record.t()}
              | {:error, reason()}
end
