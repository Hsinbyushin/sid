defmodule Sid.Catalog.Adapters.StabikatTest do
  use ExUnit.Case, async: true

  alias Sid.Catalog.Adapters.Stabikat
  alias Sid.Catalog.Record

  test "parses an empty SRU search result" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <zs:searchRetrieveResponse xmlns:zs="http://www.loc.gov/zing/srw/">
      <zs:numberOfRecords>0</zs:numberOfRecords>
    </zs:searchRetrieveResponse>
    """

    assert {:ok, []} = Stabikat.parse_search_response(xml)
  end

  test "parses a MODS catalogue record" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <zs:searchRetrieveResponse
      xmlns:zs="http://www.loc.gov/zing/srw/"
      xmlns:mods="http://www.loc.gov/mods/v3">
      <zs:records>
        <zs:record>
          <zs:recordData>
            <mods:mods>
              <mods:titleInfo>
                <mods:title>Pentadbiran Zakat Di Negara Brunei Darussalam</mods:title>
                <mods:subTitle>(1955-1991)</mods:subTitle>
              </mods:titleInfo>

              <mods:name type="personal" usage="primary">
                <mods:namePart>Hajah Saadiah binti Datu Derma Wijaya Haji Temit</mods:namePart>
              </mods:name>

              <mods:identifier type="isbn">9781234567897</mods:identifier>

              <mods:recordInfo>
                <mods:recordIdentifier source="DE-627">852699670</mods:recordIdentifier>
              </mods:recordInfo>
            </mods:mods>
          </zs:recordData>
        </zs:record>
      </zs:records>
    </zs:searchRetrieveResponse>
    """

    assert {:ok, [record]} =
             Stabikat.parse_search_response(xml)

    assert %Record{} = record
    assert record.source == "stabikat"
    assert record.record_id == "852699670"

    assert record.title ==
             "Pentadbiran Zakat Di Negara Brunei Darussalam: (1955-1991)"

    assert record.creator ==
             "Hajah Saadiah binti Datu Derma Wijaya Haji Temit"

    assert record.isbn == "9781234567897"
  end
end
