defmodule Sid.Catalog.Adapters.Fake do
  @moduledoc """
  In-memory catalog adapter used for development and automated tests.

  This adapter deliberately performs no network requests. It implements the
  same adapter contract that future real library catalog integrations will
  implement.

  Keeping the fake adapter behind the same behaviour allows SID's catalog
  functionality to be developed and tested independently of a particular
  library system or external API.
  """

  @behaviour Sid.Catalog.Adapter

  @impl true
  def search(query) when is_binary(query) do
    normalized_query =
      query
      |> String.trim()
      |> String.downcase()

    results =
      records()
      |> Enum.filter(fn record ->
        searchable_text =
          [
            record.title,
            record.author,
            record.publisher,
            record.isbn
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.join(" ")
          |> String.downcase()

        String.contains?(searchable_text, normalized_query)
      end)

    {:ok, results}
  end

  @impl true
  def lookup(identifier) when is_binary(identifier) do
    normalized_identifier = String.trim(identifier)

    case Enum.find(records(), fn record ->
           record.id == normalized_identifier or
             record.isbn == normalized_identifier
         end) do
      nil ->
        {:ok, nil}

      record ->
        {:ok, record}
    end
  end

  defp records do
    [
      %{
        id: "fake-1",
        title: "မြန်မာ့သမိုင်း",
        author: "Example Author",
        publisher: "Example Press",
        isbn: "9780000000001"
      },
      %{
        id: "fake-2",
        title: "中國歷史",
        author: "Example Author",
        publisher: "Example University Press",
        isbn: "9780000000002"
      },
      %{
        id: "fake-3",
        title: "Pāṇini and the Sanskrit Grammatical Tradition",
        author: "Example Scholar",
        publisher: "Example Academic Press",
        isbn: "9780000000003"
      }
    ]
  end
end
