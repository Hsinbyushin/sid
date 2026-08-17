defmodule Sid.Imports.Interpreter do
  @moduledoc """
  Behaviour for semantic interpretation of already extracted source records.

  Interpreters receive source text that has already been extracted
  deterministically. They may classify or structure that text, but must not
  invent bibliographic or commercial information not grounded in the source.
  """

  alias Sid.Imports.Interpretation.Result
  alias Sid.Imports.SourceRecord

  @type error ::
          :unsupported_source
          | :invalid_source
          | :invalid_model_output
          | {:backend_error, term()}

  @callback interpret(SourceRecord.t()) ::
              {:ok, Result.t()} | {:error, error()}
end
