defmodule Sid.Catalog.Adapters.FakeTest do
  use ExUnit.Case, async: true

  alias Sid.Catalog.Adapters.Fake

  describe "search/1" do
    test "ignores surrounding whitespace" do
      assert {:ok, results} = Fake.search("   Pāṇini   ")

      assert length(results) == 1
    end

    test "performs case-insensitive searches for cased scripts" do
      assert {:ok, results} = Fake.search("pĀṆINI")

      assert length(results) == 1
    end

    test "can search by ISBN" do
      assert {:ok, results} = Fake.search("9780000000002")

      assert [%{id: "fake-2"}] = results
    end
  end

  describe "lookup/1" do
    test "ignores surrounding whitespace" do
      assert {:ok, record} = Fake.lookup("  fake-2  ")

      assert record.id == "fake-2"
    end
  end
end
