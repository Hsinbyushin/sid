defmodule Sid.Catalog.Adapters.Stabikat do
  @moduledoc """
  StaBiKat catalogue adapter using the K10plus SRU/MODS interface.
  """

  @behaviour Sid.Catalog.Adapter

  alias Sid.Catalog.Record

  @type sax_state :: %{
          records: [Record.t()],
          current_record: map() | nil,
          current_element: String.t() | nil,
          current_text: [binary()],
          current_name: map() | nil,
          current_identifier_type: String.t() | nil
        }

  @impl true
  def search(_query) do
    {:error, :unavailable}
  end

  @impl true
  def lookup(_record_id) do
    {:error, :unavailable}
  end

  @spec parse_search_response(binary()) ::
          {:ok, [Record.t()]} | {:error, :invalid_response}
  def parse_search_response(xml) when is_binary(xml) do
    initial_state = %{
      records: [],
      current_record: nil,
      current_element: nil,
      current_text: [],
      current_name: nil,
      current_identifier_type: nil
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
        {:ok, Enum.reverse(state.records)}

      {:fatal_error, _location, _reason, _end_tags, _state} ->
        {:error, :invalid_response}

      {:error, _reason} ->
        {:error, :invalid_response}

      _ ->
        {:error, :invalid_response}
    end
  catch
    _kind, _reason ->
      {:error, :invalid_response}
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"mods", _qualified_name, _attributes},
         state
       ) do
    %{
      state
      | current_record: %{
          record_id: nil,
          title: nil,
          subtitle: nil,
          creator: nil,
          isbn: nil
        }
    }
  end

  defp handle_sax_event(
         {:endElement, _uri, ~c"mods", _qualified_name},
         %{current_record: current_record} = state
       )
       when not is_nil(current_record) do
    record =
      %Record{
        source: "stabikat",
        record_id: current_record.record_id,
        title: join_title(current_record.title, current_record.subtitle),
        creator: current_record.creator,
        isbn: current_record.isbn
      }

    %{
      state
      | records: [record | state.records],
        current_record: nil,
        current_element: nil,
        current_text: [],
        current_name: nil,
        current_identifier_type: nil
    }
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"name", _qualified_name, attributes},
         state
       ) do
    %{
      state
      | current_name: %{
          type: attribute_value(attributes, "type"),
          usage: attribute_value(attributes, "usage")
        }
    }
  end

  defp handle_sax_event(
         {:endElement, _uri, ~c"name", _qualified_name},
         state
       ) do
    %{state | current_name: nil}
  end

  defp handle_sax_event(
         {:startElement, _uri, ~c"identifier", _qualified_name, attributes},
         state
       ) do
    %{
      state
      | current_identifier_type: attribute_value(attributes, "type"),
        current_element: "identifier",
        current_text: []
    }
  end

  defp handle_sax_event(
         {:startElement, _uri, local_name, _qualified_name, _attributes},
         state
       )
       when local_name in [
              ~c"recordIdentifier",
              ~c"title",
              ~c"subTitle",
              ~c"namePart",
              ~c"identifier"
            ] do
    %{
      state
      | current_element: List.to_string(local_name),
        current_text: []
    }
  end

  defp handle_sax_event(
         {:characters, characters},
         %{current_element: element} = state
       )
       when not is_nil(element) do
    update_in(
      state.current_text,
      &[characters | &1]
    )
  end

  defp handle_sax_event(
         {:endElement, _uri, local_name, _qualified_name},
         %{current_record: current_record} = state
       )
       when not is_nil(current_record) do
    element = List.to_string(local_name)

    if element == state.current_element do
      value =
        state.current_text
        |> Enum.reverse()
        |> IO.iodata_to_binary()
        |> String.trim()

      state
      |> assign_value(element, value)
      |> Map.put(:current_element, nil)
      |> Map.put(:current_text, [])
    else
      state
    end
  end

  defp handle_sax_event(_event, state), do: state

  defp assign_value(state, "recordIdentifier", value) do
    put_in(state.current_record.record_id, blank_to_nil(value))
  end

  defp assign_value(state, "title", value) do
    put_in(state.current_record.title, blank_to_nil(value))
  end

  defp assign_value(state, "subTitle", value) do
    put_in(state.current_record.subtitle, blank_to_nil(value))
  end

  defp assign_value(
         %{current_name: %{usage: "primary"}} = state,
         "namePart",
         value
       ) do
    put_in(state.current_record.creator, blank_to_nil(value))
  end

  defp assign_value(
         %{current_identifier_type: type} = state,
         "identifier",
         value
       )
       when is_binary(type) do
    state =
      if String.downcase(type) == "isbn" do
        put_in(
          state.current_record.isbn,
          blank_to_nil(value)
        )
      else
        state
      end

    %{state | current_identifier_type: nil}
  end

  defp assign_value(state, _element, _value), do: state

  defp join_title(nil, nil), do: nil
  defp join_title(title, nil), do: title
  defp join_title(nil, subtitle), do: subtitle
  defp join_title(title, subtitle), do: "#{title}: #{subtitle}"

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp attribute_value(attributes, expected_name)
       when is_list(attributes) do
    Enum.find_value(
      attributes,
      &attribute_value(&1, expected_name)
    )
  end

  defp attribute_value(
         {_uri, _prefix, attribute_name, value},
         expected_name
       ) do
    if List.to_string(attribute_name) == expected_name do
      List.to_string(value)
    end
  end

  defp attribute_value(_attribute, _expected_name), do: nil
end
