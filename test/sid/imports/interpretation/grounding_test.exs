defmodule Sid.Imports.Interpretation.GroundingTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Interpretation.Grounding
  alias Sid.Imports.Interpretation.Result

  test "accepts values grounded in source lines" do
    result = %Result{
      source_lines: [
        "Festival Rambu Solo / Heti Sorenda",
        "Arts"
      ],
      title: "Festival Rambu Solo",
      responsibility_statement: "Heti Sorenda",
      vendor_classifications: ["Arts"]
    }

    assert :ok = Grounding.validate(result)
  end

  test "rejects invented textual values" do
    result = %Result{
      source_lines: [
        "Festival Rambu Solo / Heti Sorenda",
        "Arts"
      ],
      title: "Festival Rambu Solo",
      vendor_classifications: ["History"]
    }

    assert {:error, {:ungrounded, :vendor_classification, "History"}} =
             Grounding.validate(result)
  end

  test "normalizes whitespace before checking grounding" do
    result = %Result{
      source_lines: [
        "Festival Rambu Solo / Heti Sorenda"
      ],
      title: "Festival   Rambu Solo"
    }

    assert :ok = Grounding.validate(result)
  end

  test "allows source material to remain unresolved" do
    result = %Result{
      source_lines: [
        "Sociology/Culture Studies",
        "0",
        "শিমুলজাবালি"
      ],
      vendor_classifications: [
        "Sociology/Culture Studies"
      ],
      unresolved: [
        "0",
        "শিমুলজাবালি"
      ]
    }

    assert :ok = Grounding.validate(result)
  end
end
