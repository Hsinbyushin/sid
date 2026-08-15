defmodule Sid.Imports.Validators.IsbnTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Validators.Isbn

  describe "valid?/1" do
    test "accepts a valid ISBN-13" do
      assert Isbn.valid?("9783161484100")
    end

    test "accepts a valid ISBN-13 containing hyphens" do
      assert Isbn.valid?("978-3-16-148410-0")
    end

    test "accepts whitespace around an ISBN" do
      assert Isbn.valid?(" 9783161484100 ")
    end

    test "rejects an ISBN-13 with an invalid checksum" do
      refute Isbn.valid?("9783161484101")
    end

    test "accepts a valid ISBN-10" do
      assert Isbn.valid?("0306406152")
    end

    test "accepts a valid ISBN-10 whose check digit is X" do
      assert Isbn.valid?("080442957X")
    end

    test "accepts lowercase x as an ISBN-10 check digit" do
      assert Isbn.valid?("080442957x")
    end

    test "rejects X outside the ISBN-10 check digit position" do
      refute Isbn.valid?("08044295X7")
    end

    test "rejects an ISBN-10 with an invalid checksum" do
      refute Isbn.valid?("0306406153")
    end

    test "rejects malformed vendor identifiers" do
      refute Isbn.valid?("9786041-27798")
    end

    test "rejects arbitrary text" do
      refute Isbn.valid?("not an isbn")
    end

    test "rejects nil" do
      refute Isbn.valid?(nil)
    end
  end
end
