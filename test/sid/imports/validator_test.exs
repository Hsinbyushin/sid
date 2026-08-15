defmodule Sid.Imports.ValidatorTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.{
    ExtractedOffer,
    Identifier,
    SourceRecord,
    Validator
  }

  test "marks a valid ISBN as valid" do
    offer =
      extracted_offer([
        %Identifier{
          scheme: :isbn,
          value: "9783161484100",
          validation_status: :unchecked
        }
      ])

    validated = Validator.validate(offer)

    assert [
             %Identifier{
               value: "9783161484100",
               validation_status: :valid
             }
           ] = validated.identifiers
  end

  test "marks an invalid ISBN as invalid without changing its value" do
    source_value = "9786041-27798"

    offer =
      extracted_offer([
        %Identifier{
          scheme: :isbn,
          value: source_value,
          validation_status: :unchecked
        }
      ])

    validated = Validator.validate(offer)

    assert [
             %Identifier{
               value: ^source_value,
               validation_status: :invalid
             }
           ] = validated.identifiers
  end

  test "leaves unsupported identifier schemes unchecked" do
    offer =
      extracted_offer([
        %Identifier{
          scheme: :issn,
          value: "1906-005X",
          validation_status: :unchecked
        }
      ])

    validated = Validator.validate(offer)

    assert [
             %Identifier{
               scheme: :issn,
               value: "1906-005X",
               validation_status: :unchecked
             }
           ] = validated.identifiers
  end

  test "does not modify the original source record" do
    raw = %{
      "ISBN" => "9786041-27798",
      "Unknown Vendor Field" => "preserve me"
    }

    source = %SourceRecord{
      format: :xlsx,
      source_filename: "vendor.xlsx",
      raw: raw
    }

    offer = %ExtractedOffer{
      source: source,
      identifiers: [
        %Identifier{
          scheme: :isbn,
          value: "9786041-27798"
        }
      ]
    }

    validated = Validator.validate(offer)

    assert validated.source.raw == raw
  end

  defp extracted_offer(identifiers) do
    %ExtractedOffer{
      source: %SourceRecord{
        format: :xlsx,
        source_filename: "vendor.xlsx",
        raw: %{}
      },
      identifiers: identifiers
    }
  end
end
