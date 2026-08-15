defmodule Sid.Imports.Extractors.Docx do
  @moduledoc """
  Vendor-neutral DOCX paragraph extractor.

  DOCX files are ZIP containers containing Office Open XML documents.

  This extractor reads only `word/document.xml`, which represents the main
  document body. Headers and footers are deliberately not included.

  Each Word paragraph is converted into a
  `Sid.Imports.Extractors.Docx.Paragraph`.

  The extractor preserves:

  - paragraph order;
  - complete visible paragraph text;
  - paragraph style identifiers.

  It does not interpret titles, ISBNs, prices, subjects, categories, or other
  vendor-specific information.

  XML is processed with Erlang's SAX parser so namespace prefixes do not become
  part of SID's document logic. The parser works with XML local names such as
  `p`, `t`, and `pStyle`.
  """

  alias Sid.Imports.Extractors.Docx.Paragraph

  @document_path ~c"word/document.xml"

  @type sax_state :: %{
          paragraphs: [Paragraph.t()],
          current_paragraph: map() | nil,
          in_text: boolean(),
          next_index: pos_integer()
        }

  @spec extract(Path.t()) ::
          {:ok, [Paragraph.t()]} | {:error, term()}
  def extract(path) when is_binary(path) do
    with {:ok, xml} <- read_document_xml(path),
         {:ok, paragraphs} <- from_xml(xml) do
      {:ok, paragraphs}
    end
  end

  @doc """
  Extracts paragraphs from DOCX `word/document.xml` content.

  This function is public so XML interpretation can be tested independently
  from ZIP archive handling.
  """
  @spec from_xml(binary()) ::
          {:ok, [Paragraph.t()]} | {:error, term()}
  def from_xml(xml) when is_binary(xml) do
    initial_state = %{
      paragraphs: [],
      current_paragraph: nil,
      in_text: false,
      next_index: 1
    }

    event_fun = fn event, _location, state ->
      handle_sax_event(event, state)
    end

    options = [
      event_fun: event_fun,
      event_state: initial_state,
      encoding: :utf8,
      external_entities: :none,
      fail_undeclared_ref: false
    ]

    case :xmerl_sax_parser.stream(xml, options) do
      {:ok, state, _rest} ->
        {:ok, Enum.reverse(state.paragraphs)}

      {:fatal_error, location, reason, _end_tags, _state} ->
        {:error, {:invalid_docx_xml, {location, reason}}}

      {:error, reason} ->
        {:error, {:invalid_docx_xml, reason}}

      other ->
        {:error, {:invalid_docx_xml, other}}
    end
  catch
    kind, reason ->
      {:error, {:invalid_docx_xml, {kind, reason}}}
  end

  defp read_document_xml(path) do
    case :zip.extract(
           String.to_charlist(path),
           [:memory, {:file_list, [@document_path]}]
         ) do
      {:ok, files} ->
        case Enum.find(files, fn
               {@document_path, _content} -> true
               _ -> false
             end) do
          {@document_path, content} ->
            {:ok, IO.iodata_to_binary(content)}

          nil ->
            {:error, :document_xml_not_found}
        end

      {:error, reason} ->
        {:error, {:invalid_docx_archive, reason}}
    end
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"br", _qualified_name, _attributes},
         %{current_paragraph: paragraph} = state
       )
       when not is_nil(paragraph) do
    update_in(
      state.current_paragraph.text_parts,
      &["\n" | &1]
    )
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"tab", _qualified_name, _attributes},
         %{current_paragraph: paragraph} = state
       )
       when not is_nil(paragraph) do
    update_in(
      state.current_paragraph.text_parts,
      &["\t" | &1]
    )
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"p", _qualified_name, _attributes},
         state
       ) do
    %{
      state
      | current_paragraph: %{
          text_parts: [],
          style: nil
        }
    }
  end

  defp handle_sax_event(
         {:endElement, _uri, ~c"p", _qualified_name},
         %{current_paragraph: paragraph} = state
       )
       when not is_nil(paragraph) do
    extracted_paragraph = %Paragraph{
      index: state.next_index,
      text:
        paragraph.text_parts
        |> Enum.reverse()
        |> IO.iodata_to_binary(),
      style: paragraph.style
    }

    %{
      state
      | paragraphs: [extracted_paragraph | state.paragraphs],
        current_paragraph: nil,
        in_text: false,
        next_index: state.next_index + 1
    }
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"t", _qualified_name, _attributes},
         %{current_paragraph: paragraph} = state
       )
       when not is_nil(paragraph) do
    %{state | in_text: true}
  end

  defp handle_sax_event(
         {:endElement, _uri, ~c"t", _qualified_name},
         state
       ) do
    %{state | in_text: false}
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"pStyle", _qualified_name, attributes},
         %{current_paragraph: paragraph} = state
       )
       when not is_nil(paragraph) do
    style =
      Enum.find_value(attributes, fn attribute ->
        attribute_value(attribute, "val")
      end)

    put_in(state.current_paragraph.style, style)
  end

  defp handle_sax_event(
         {:characters, characters},
         %{
           current_paragraph: paragraph,
           in_text: true
         } = state
       )
       when not is_nil(paragraph) do
    text = List.to_string(characters)

    update_in(
      state.current_paragraph.text_parts,
      &[text | &1]
    )
  end

  defp handle_sax_event(_event, state), do: state

  # SAX attribute tuple shapes are an implementation detail of xmerl. Rather
  # than bind SID to the namespace prefix, inspect the local-name position and
  # preserve only the attribute value needed for paragraph styles.
  defp attribute_value(
         {_uri, _prefix, attribute_name, value},
         expected_attribute_name
       ) do
    if List.to_string(attribute_name) == expected_attribute_name do
      List.to_string(value)
    end
  end

  defp attribute_value(_attribute, _expected_attribute_name), do: nil
end
