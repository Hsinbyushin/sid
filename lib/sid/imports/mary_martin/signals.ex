defmodule Sid.Imports.MaryMartin.Signals do
  @moduledoc """
  Deterministic recognition of structural signals in Mary Martin source data.

  These functions identify source patterns without assigning broader semantic
  meaning to ambiguous text.
  """

  @spec parse_price(String.t()) ::
          {:ok,
           %{
             amount: Decimal.t(),
             currency: String.t(),
             qualifier: String.t() | nil,
             binding: String.t()
           }}
          | :error
  def parse_price(text) when is_binary(text) do
    regex =
      ~r/^\s*(?<currency>USD|BND|\$)\s*:?\s*(?<amount>\d+(?:[.,]\d+)?)\s*(?:\((?<qualifier>[^)]+)\))?\s*\/\s*(?<binding>[[:alnum:]-]+)\s*$/u

    case Regex.named_captures(regex, text) do
      nil ->
        :error

      captures ->
        amount =
          captures["amount"]
          |> String.replace(",", ".")
          |> Decimal.new()
          |> Decimal.round(2)

        {:ok,
         %{
           amount: amount,
           currency: captures["currency"],
           qualifier: blank_to_nil(captures["qualifier"]),
           binding: captures["binding"]
         }}
    end
  end

  @spec price?(String.t()) :: boolean()
  def price?(text) when is_binary(text) do
    match?({:ok, _}, parse_price(text))
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  @spec identifier_candidate(String.t()) ::
          {:ok, %{scheme: :isbn, value: String.t()}} | :error
  def identifier_candidate(text) when is_binary(text) do
    compact =
      text
      |> String.replace(~r/[\s-]/u, "")

    if Regex.match?(~r/^\d{9}[\dXx]$|^\d{11,13}$/u, compact) do
      {:ok,
       %{
         scheme: :isbn,
         value: text
       }}
    else
      :error
    end
  end

  @spec physical_description?(String.t()) :: boolean()
  def physical_description?(text) when is_binary(text) do
    Regex.match?(
      ~r/(?:\d+\s*p\.?|[ivxlcdm]+\s*[,+.]\s*\d+\s*p\.?|\d+\s*v\.)(?:\s*;\s*[\d.,x]+\s*cm\.?)?/iu,
      text
    )
  end

  @spec publication_statement?(String.t()) :: boolean()
  def publication_statement?(text) when is_binary(text) do
    Regex.match?(
      ~r/:\s*.+(?:19|20)\d{2}\s*$/u,
      text
    )
  end

  @spec weight?(String.t()) :: boolean()
  def weight?(text) when is_binary(text) do
    Regex.match?(
      ~r/^\s*\d+(?:[.,]\d+)?\s*(?:gm\.?|kg\.?)\s*$/iu,
      text
    )
  end

  @spec vendor_url(String.t()) :: {:ok, String.t()} | :error
  def vendor_url(text) when is_binary(text) do
    case Regex.run(
           ~r{https?://(?:www\.)?marymartin\.com/web\?pid=\d+}iu,
           text
         ) do
      [url] -> {:ok, url}
      _ -> :error
    end
  end

  @spec vendor_url?(String.t()) :: boolean()
  def vendor_url?(text) when is_binary(text) do
    match?({:ok, _}, vendor_url(text))
  end
end
