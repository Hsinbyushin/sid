defmodule Sid.CatalogTest do
  use ExUnit.Case, async: true

  alias Sid.Catalog

  describe "search/1" do
    test "returns matching catalog records through the configured adapter" do
      assert {:ok, results} = Catalog.search("Pāṇini")

      assert Enum.any?(results, fn record ->
               record.title == "Pāṇini and the Sanskrit Grammatical Tradition"
             end)
    end

    test "returns an empty list when no records match" do
      assert {:ok, []} =
               Catalog.search("This title definitely does not exist")
    end

    test "preserves Unicode search queries" do
      assert {:ok, results} = Catalog.search("မြန်မာ")

      assert Enum.any?(results, fn record ->
               record.title == "မြန်မာ့သမိုင်း"
             end)
    end

    test "supports CJK catalog data" do
      assert {:ok, results} = Catalog.search("中國")

      assert Enum.any?(results, fn record ->
               record.title == "中國歷史"
             end)
    end
  end

  describe "lookup/1" do
    test "looks up a record by adapter identifier" do
      assert {:ok, record} = Catalog.lookup("fake-1")

      assert record.id == "fake-1"
      assert record.title == "မြန်မာ့သမိုင်း"
    end

    test "looks up a record by ISBN" do
      assert {:ok, record} = Catalog.lookup("9780000000003")

      assert record.title ==
               "Pāṇini and the Sanskrit Grammatical Tradition"
    end

    test "returns nil when an identifier is unknown" do
      assert {:ok, nil} = Catalog.lookup("unknown-record")
    end
  end

  defmodule AlternativeAdapter do
    @behaviour Sid.Catalog.Adapter

    @impl true
    def search(query) do
      {:ok,
       [
         %{
           id: "alternative-1",
           title: "Alternative catalog result",
           query: query
         }
       ]}
    end

    @impl true
    def lookup(identifier) do
      {:ok,
       %{
         id: identifier,
         title: "Alternative catalog record"
       }}
    end
  end

  describe "adapter configuration" do
    test "catalog operations are delegated to the configured adapter" do
      original_adapter =
        Application.fetch_env!(:sid, :catalog_adapter)

      try do
        Application.put_env(
          :sid,
          :catalog_adapter,
          AlternativeAdapter
        )

        assert {:ok, [record]} = Catalog.search("test query")

        assert record.id == "alternative-1"
        assert record.query == "test query"

        assert {:ok, lookup_record} =
                 Catalog.lookup("external-id-123")

        assert lookup_record.id == "external-id-123"
      after
        Application.put_env(
          :sid,
          :catalog_adapter,
          original_adapter
        )
      end
    end
  end
end
