defmodule Sid.Imports.Interpretation.MaryMartinInput do
  @moduledoc """
  Prepares Mary Martin source records for semantic interpretation.

  Source material that can be classified deterministically is separated from
  material that still requires semantic interpretation.
  """

  alias Sid.Imports.Interpretation.Input
  alias Sid.Imports.SourceRecord
  alias Sid.Imports.MaryMartin.Signals

  @spec prepare(SourceRecord.t()) :: Input.t()
  def prepare(%SourceRecord{raw: paragraphs}) do
    source_lines =
      paragraphs
      |> Enum.flat_map(&logical_lines/1)
      |> Enum.reject(&(&1 == ""))

    {deterministic, remaining_lines} =
      Enum.reduce(
        source_lines,
        {%{}, []},
        &classify_line/2
      )

    %Input{
      source_lines: source_lines,
      remaining_lines: Enum.reverse(remaining_lines),
      deterministic: deterministic
    }
  end

  defp classify_line(line, {deterministic, remaining}) do
    cond do
      Signals.vendor_url?(line) ->
        {:ok, url} = Signals.vendor_url(line)

        {
          Map.put(deterministic, :vendor_url, url),
          remaining
        }

      Signals.weight?(line) ->
        {
          Map.put(deterministic, :weight, line),
          remaining
        }

      Signals.price?(line) ->
        put_price(line, deterministic, remaining)

      match?({:ok, _}, Signals.identifier_candidate(line)) ->
        put_identifier(line, deterministic, remaining)

      Signals.physical_description?(line) ->
        {
          Map.put(deterministic, :physical_description, line),
          remaining
        }

      Signals.publication_statement?(line) ->
        {
          Map.put(deterministic, :publication_statement, line),
          remaining
        }

      Signals.vendor_url?(line) ->
        {:ok, url} = Signals.vendor_url(line)

        {
          Map.put(deterministic, :vendor_url, url),
          remaining
        }

      Signals.weight?(line) ->
        {
          Map.put(deterministic, :weight, line),
          remaining
        }

      true ->
        {deterministic, [line | remaining]}
    end
  end

  defp put_identifier(line, deterministic, remaining) do
    {:ok, identifier} =
      Signals.identifier_candidate(line)

    identifiers =
      Map.get(deterministic, :identifiers, [])

    deterministic =
      Map.put(
        deterministic,
        :identifiers,
        identifiers ++ [identifier]
      )

    {deterministic, remaining}
  end

  defp put_price(line, deterministic, remaining) do
    {:ok, price} = Signals.parse_price(line)

    deterministic =
      deterministic
      |> Map.put(:price_source, line)
      |> Map.put(:price_amount, price.amount)
      |> Map.put(:price_currency, price.currency)
      |> Map.put(:price_qualifier, price.qualifier)
      |> Map.put(:binding, price.binding)

    {deterministic, remaining}
  end

  defp logical_lines(%{text: text}) when is_binary(text) do
    text
    |> String.split(~r/\r?\n/u)
    |> Enum.map(&String.trim/1)
  end
end
