defmodule Sid.Imports.Parsers.MaryMartin do
  @moduledoc """
  Deterministic parser for Mary Martin vendor offer records.

  The parser receives a `SourceRecord` whose raw value is a list of DOCX
  paragraphs previously segmented into one candidate offer.

  It extracts only information that can be identified by deterministic source
  patterns.

  Unresolved source material is preserved in `unparsed` rather than guessed.

  This parser does not validate identifiers. Identifier validation remains a
  separate pipeline stage handled by `Sid.Imports.Validator`.
  """

  @behaviour Sid.Imports.Parser

  alias Sid.Imports.{
    ExtractedOffer,
    Identifier,
    SourceRecord,
    TextContent
  }

  alias Sid.Imports.Extractors.Docx.Paragraph

  @impl true
  @spec parse(SourceRecord.t()) ::
          {:ok, ExtractedOffer.t()} | {:error, term()}
  def parse(
        %SourceRecord{
          format: :docx,
          raw: paragraphs
        } = source
      )
      when is_list(paragraphs) do
    lines =
      paragraphs
      |> Enum.flat_map(&lines_from_paragraph/1)
      |> Enum.reject(&(&1.text == ""))
      |> drop_document_preamble()

    case lines do
      [] ->
        {:error, :not_offer}

      _ ->
        if offer_candidate?(lines) do
          parse_offer(source, lines)
        else
          {:error, :not_offer}
        end
    end
  end

  def parse(%SourceRecord{}) do
    {:error, :invalid_raw_record}
  end

  defp drop_document_preamble(lines) do
    if mary_martin_preamble?(lines) do
      drop_through_preamble(lines)
    else
      lines
    end
  end

  defp mary_martin_preamble?(lines) do
    Enum.any?(lines, fn line ->
      line.text == "Mary Martin Booksellers Pte Ltd"
    end)
  end

  defp drop_through_preamble(lines) do
    case Enum.find_index(lines, &preamble_end?/1) do
      nil ->
        lines

      index ->
        Enum.drop(lines, index + 1)
    end
  end

  defp preamble_end?(%{text: text}) do
    text
    |> String.downcase()
    |> String.contains?("www.marymartin.com")
  end

  defp parse_offer(source, [title_line | remaining]) do
    {title, responsibility_statement} =
      split_title_responsibility(title_line.text)

    publication_index =
      Enum.find_index(
        remaining,
        &publication_statement?/1
      )

    identifier_index =
      Enum.find_index(
        remaining,
        &identifier?(&1.text)
      )

    state = %{
      source: source,
      title: title,
      responsibility_statement: responsibility_statement,
      publication_statement: nil,
      physical_description: nil,
      edition_statement: nil,
      identifier_index: identifier_index,
      identifiers: [],
      inferred_category: nil,
      subjects: [],
      series_statements: [],
      notes: [],
      descriptions: [],
      price_amount: nil,
      price_currency: nil,
      price_qualifier: nil,
      binding: nil,
      weight: nil,
      vendor_url: nil,
      unparsed: [],
      publication_index: publication_index,
      commercial_seen: false
    }

    parsed =
      remaining
      |> Enum.with_index()
      |> Enum.reduce(
        state,
        &classify_line/2
      )

    offer =
      %ExtractedOffer{
        source: source,
        vendor_url: parsed.vendor_url,
        titles: [
          %TextContent{
            role: :primary_title,
            text: parsed.title
          }
        ],
        descriptions:
          Enum.map(
            parsed.descriptions,
            fn text ->
              %TextContent{
                role: :description,
                text: text
              }
            end
          ),
        responsibility_statement: parsed.responsibility_statement,
        publication_statement: parsed.publication_statement,
        physical_description: parsed.physical_description,
        edition_statement: parsed.edition_statement,
        identifiers: Enum.reverse(parsed.identifiers),
        series_statements: Enum.reverse(parsed.series_statements),
        subjects: Enum.reverse(parsed.subjects),
        notes: Enum.reverse(parsed.notes),
        vendor_category:
          get_in(source.metadata, [:vendor_category]) ||
            parsed.inferred_category,
        price_amount: parsed.price_amount,
        price_currency: parsed.price_currency,
        price_qualifier: parsed.price_qualifier,
        binding: parsed.binding,
        weight: parsed.weight,
        unparsed: Enum.reverse(parsed.unparsed)
      }

    {:ok, offer}
  end

  defp classify_line(
         {%{style: "ListParagraph", text: text}, _index},
         state
       ) do
    update_in(
      state.subjects,
      &[text | &1]
    )
  end

  defp classify_line(
         {%{text: text}, index},
         state
       ) do
    cond do
      is_nil(state.vendor_url) and
          mary_martin_url?(text) ->
        %{state | vendor_url: extract_mary_martin_url(text)}

      is_nil(state.price_amount) and
          match?({:ok, _}, parse_price(text)) ->
        {:ok, price} = parse_price(text)

        %{
          state
          | price_amount: price.amount,
            price_currency: price.currency,
            price_qualifier: price.qualifier,
            binding: price.binding,
            commercial_seen: true
        }

      is_nil(state.weight) and weight?(text) ->
        %{
          state
          | weight: text,
            commercial_seen: true
        }

      identifier?(text) ->
        identifier =
          %Identifier{
            scheme: :isbn,
            value: text,
            validation_status: :unchecked
          }

        update_in(
          state.identifiers,
          &[identifier | &1]
        )

      is_nil(state.publication_statement) and
          publication_statement?(%{text: text}) ->
        %{state | publication_statement: text}

      is_nil(state.physical_description) and
          physical_description?(text) ->
        %{state | physical_description: text}

      is_nil(state.publication_statement) and
          publication_statement?(%{text: text}) ->
        %{state | publication_statement: text}

      is_nil(state.physical_description) and
          physical_description?(text) ->
        %{state | physical_description: text}

      category_candidate?(text, index, state) ->
        %{state | inferred_category: text}

      is_nil(state.edition_statement) and
          edition_statement?(text) ->
        %{state | edition_statement: text}

      is_nil(state.edition_statement) and
          edition_statement?(text) ->
        %{state | edition_statement: text}

      note?(text) ->
        update_in(
          state.notes,
          &[text | &1]
        )

      before_publication?(
        index,
        state.publication_index
      ) ->
        update_in(
          state.series_statements,
          &[text | &1]
        )

      description?(text, state) ->
        update_in(
          state.descriptions,
          &(&1 ++ [text])
        )

      true ->
        update_in(
          state.unparsed,
          &[text | &1]
        )
    end
  end

  defp category_candidate?(text, index, state) do
    is_nil(state.inferred_category) and
      not is_nil(state.physical_description) and
      not is_nil(state.identifier_index) and
      index < state.identifier_index and
      state.identifiers == [] and
      not identifier?(text) and
      not price_line?(text) and
      not weight?(text) and
      not note?(text) and
      not mary_martin_url?(text) and
      plausible_category_text?(text)
  end

  defp plausible_category_text?(text) do
    length = String.length(text)

    length >= 2 and
      length <= 100 and
      not String.contains?(text, ".") and
      not String.contains?(text, ":")
  end

  defp price_line?(text) do
    match?({:ok, _}, parse_price(text))
  end

  defp lines_from_paragraph(%Paragraph{} = paragraph) do
    paragraph.text
    |> String.split(~r/\R/u)
    |> Enum.map(fn text ->
      %{
        index: paragraph.index,
        style: paragraph.style,
        text: String.trim(text)
      }
    end)
  end

  defp offer_candidate?(lines) do
    score =
      [
        Enum.any?(lines, &mary_martin_url?(&1.text)),
        Enum.any?(lines, &price?/1),
        Enum.any?(lines, &publication_statement?/1)
      ]
      |> Enum.count(& &1)

    score >= 2
  end

  defp publication_statement?(%{text: text}) do
    Regex.match?(
      ~r/:\s*.+(?:19|20)\d{2}\s*$/u,
      text
    )
  end

  defp price?(%{text: text}) do
    match?({:ok, _}, parse_price(text))
  end

  defp parse_price(text) do
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

  defp identifier?(text) do
    compact =
      text
      |> String.replace(~r/[\s-]/u, "")

    Regex.match?(
      ~r/^\d{9}[\dXx]$|^\d{11,13}$|^\d{13}$/u,
      compact
    )
  end

  defp physical_description?(text) do
    Regex.match?(
      ~r/(?:\d+\s*p\.?|[ivxlcdm]+\s*[,+.]\s*\d+\s*p\.?|\d+\s*v\.)(?:\s*;\s*[\d.,x]+\s*cm\.?)?/iu,
      text
    )
  end

  defp edition_statement?(text) do
    Regex.match?(
      ~r/\b(?:edition|edisi)\b/iu,
      text
    )
  end

  defp weight?(text) do
    Regex.match?(
      ~r/^\s*\d+(?:[.,]\d+)?\s*(?:gm\.?|kg\.?)\s*$/iu,
      text
    )
  end

  defp mary_martin_url?(text) do
    Regex.match?(
      ~r{https?://(?:www\.)?marymartin\.com/web\?pid=\d+}iu,
      text
    )
  end

  defp extract_mary_martin_url(text) do
    case Regex.run(
           ~r{https?://(?:www\.)?marymartin\.com/web\?pid=\d+}iu,
           text
         ) do
      [url] -> url
      _ -> nil
    end
  end

  defp note?(text) do
    bibliography_or_index?(text) or
      short_parenthesized?(text)
  end

  defp bibliography_or_index?(text) do
    Regex.match?(
      ~r/^Includes?\s+(?:Bibliography|Index)\.?$/iu,
      text
    )
  end

  defp short_parenthesized?(text) do
    String.length(text) <= 120 and
      String.starts_with?(text, "(") and
      String.ends_with?(text, ")")
  end

  defp description?(text, state) do
    state.commercial_seen and
      String.length(text) >= 60 and
      not mary_martin_url?(text)
  end

  defp before_publication?(
         _index,
         nil
       ),
       do: false

  defp before_publication?(
         index,
         publication_index
       ) do
    index < publication_index
  end

  defp split_title_responsibility(text) do
    case split_at_last_slash(text) do
      {title, responsibility}
      when is_binary(title) and
             is_binary(responsibility) and
             title != "" and
             responsibility != "" ->
        {
          String.trim(title),
          String.trim(responsibility)
        }

      _ ->
        {String.trim(text), nil}
    end
  end

  defp split_at_last_slash(text) do
    case :binary.matches(text, "/") do
      [] ->
        {text, nil}

      matches ->
        {position, 1} =
          List.last(matches)

        title =
          binary_part(
            text,
            0,
            position
          )

        responsibility =
          binary_part(
            text,
            position + 1,
            byte_size(text) - position - 1
          )

        {title, responsibility}
    end
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
