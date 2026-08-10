defmodule Sid.Catalog do
  @moduledoc """
  Provides SID's public interface for catalogue access.

  Application code should use this module instead of calling a concrete
  catalogue adapter directly.

  The active adapter is selected through application configuration. This
  allows SID to support different library catalogues without coupling the
  application domain to one particular external API.
  """

  @doc """
  Searches the configured catalogue.

  The search query is forwarded to the configured catalogue adapter. Results
  are returned using SID's internal catalogue record representation.
  """
  def search(query) when is_binary(query) do
    adapter().search(query)
  end

  @doc """
  Retrieves one catalogue record by its catalogue-specific identifier.
  """
  def lookup(record_id) when is_binary(record_id) do
    adapter().lookup(record_id)
  end

  defp adapter do
    Application.fetch_env!(:sid, :catalog_adapter)
  end
end
