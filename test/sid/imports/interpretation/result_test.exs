defmodule Sid.Imports.Interpretation.ResultTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Interpretation.Result

  test "preserves the source lines used for interpretation" do
    lines = [
      "Festival Rambu Solo / Heti Sorenda",
      "Arts"
    ]

    result = %Result{
      source_lines: lines,
      title: "Festival Rambu Solo",
      responsibility_statement: "Heti Sorenda",
      vendor_classifications: ["Arts"],
      unresolved: []
    }

    assert result.source_lines == lines
    assert result.title == "Festival Rambu Solo"
    assert result.responsibility_statement == "Heti Sorenda"
    assert result.vendor_classifications == ["Arts"]
    assert result.unresolved == []
  end
end
