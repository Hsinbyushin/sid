defmodule Sid.Imports.Interpretation.Grounding do
  @moduledoc """
  Deterministic grounding checks for interpreted import data.

  These checks do not decide whether an interpretation is semantically correct.
  They only ensure that source-derived text values remain traceable to the
  supplied source material.
  """

  alias Sid.Imports.Interpretation.Result

  @spec validate(Result.t()) ::
          :ok | {:error, {:ungrounded, atom(), String.t()}}
  def validate(%Result{} = result) do
    source_text =
      result.source_lines
      |> Enum.join("\n")
      |> normalize()

    result
    |> grounded_values()
    |> Enum.reduce_while(:ok, fn {field, value}, :ok ->
      if grounded?(value, source_text) do
        {:cont, :ok}
      else
        {:halt, {:error, {:ungrounded, field, value}}}
      end
    end)
  end

  defp grounded_values(result) do
    [
      {:title, result.title},
      {:responsibility_statement, result.responsibility_statement}
    ]
    |> Enum.reject(fn {_field, value} ->
      is_nil(value) or value == ""
    end)
    |> Kernel.++(
      Enum.map(
        result.vendor_classifications,
        &{:vendor_classification, &1}
      )
    )
    |> Kernel.++(
      Enum.map(
        result.descriptions,
        &{:description, &1}
      )
    )
    |> Kernel.++(
      Enum.map(
        result.notes,
        &{:note, &1}
      )
    )
    |> Kernel.++(
      Enum.map(
        result.unresolved,
        &{:unresolved, &1}
      )
    )
  end

  defp grounded?(nil, _source_text), do: true

  defp grounded?(value, source_text) when is_binary(value) do
    normalized_value = normalize(value)

    normalized_value != "" and
      String.contains?(source_text, normalized_value)
  end

  defp grounded?(_value, _source_text), do: false

  defp normalize(value) do
    value
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end
end
