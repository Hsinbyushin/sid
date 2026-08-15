defmodule Sid.Imports.Validator do
  @moduledoc """
  Validates structured values in an extracted vendor offer.

  Validation is a separate processing stage after parsing.

  The validator must preserve source values. It may update validation metadata
  on structured interpretations, but it must not silently correct, discard, or
  replace data supplied by the vendor.
  """

  alias Sid.Imports.{ExtractedOffer, Identifier}
  alias Sid.Imports.Validators.Isbn

  @spec validate(ExtractedOffer.t()) :: ExtractedOffer.t()
  def validate(%ExtractedOffer{} = offer) do
    %{
      offer
      | identifiers:
          Enum.map(
            offer.identifiers,
            &validate_identifier/1
          )
    }
  end

  defp validate_identifier(%Identifier{scheme: :isbn} = identifier) do
    status =
      if Isbn.valid?(identifier.value) do
        :valid
      else
        :invalid
      end

    %{identifier | validation_status: status}
  end

  defp validate_identifier(%Identifier{} = identifier) do
    identifier
  end
end
