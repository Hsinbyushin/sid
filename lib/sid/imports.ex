defmodule Sid.Imports do
  @moduledoc """
  Public entry point for SID's deterministic import pipeline.

  The pipeline keeps file extraction, vendor-specific parsing, and validation
  as separate processing stages.

  It does not persist imported offers and does not perform catalogue matching
  or acquisition decisions.
  """

  alias Sid.Imports.ExtractedOffer
  alias Sid.Imports.Validator

  @type process_error ::
          {:parse_error, term()}

  @spec process(struct(), module()) ::
          {:ok, ExtractedOffer.t()} | {:error, process_error()}
  def process(source_record, parser) when is_atom(parser) do
    case parser.parse(source_record) do
      {:ok, offer} ->
        {:ok, Validator.validate(offer)}

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  @spec process_many([struct()], module()) ::
          {[
             ExtractedOffer.t()
           ],
           [
             {struct(), process_error()}
           ]}
  def process_many(source_records, parser)
      when is_list(source_records) and is_atom(parser) do
    source_records
    |> Enum.reduce({[], []}, fn source_record, {offers, errors} ->
      case process(source_record, parser) do
        {:ok, offer} ->
          {[offer | offers], errors}

        {:error, reason} ->
          {offers, [{source_record, reason} | errors]}
      end
    end)
    |> then(fn {offers, errors} ->
      {Enum.reverse(offers), Enum.reverse(errors)}
    end)
  end
end
