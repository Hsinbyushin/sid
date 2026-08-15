defmodule Sid.Imports.Extractors.DocxTest do
  use ExUnit.Case, async: true

  alias Sid.Imports.Extractors.Docx
  alias Sid.Imports.Extractors.Docx.Paragraph

  test "extracts paragraph text in document order" do
    xml =
      document_xml("""
      <w:p>
        <w:r>
          <w:t>First paragraph</w:t>
        </w:r>
      </w:p>

      <w:p>
        <w:r>
          <w:t>Second paragraph</w:t>
        </w:r>
      </w:p>
      """)

    assert {:ok, paragraphs} =
             Docx.from_xml(xml)

    assert [
             %Paragraph{
               index: 1,
               text: "First paragraph"
             },
             %Paragraph{
               index: 2,
               text: "Second paragraph"
             }
           ] = paragraphs
  end

  test "joins text split across multiple Word runs" do
    xml =
      document_xml("""
      <w:p>
        <w:r>
          <w:t>Long </w:t>
        </w:r>
        <w:r>
          <w:t>book </w:t>
        </w:r>
        <w:r>
          <w:t>title</w:t>
        </w:r>
      </w:p>
      """)

    assert {:ok, [paragraph]} =
             Docx.from_xml(xml)

    assert paragraph.text == "Long book title"
  end

  test "includes text nested inside hyperlinks" do
    xml =
      document_xml("""
      <w:p>
        <w:hyperlink r:id="rId1">
          <w:r>
            <w:t>https://www.marymartin.com/web?pid=908614</w:t>
          </w:r>
        </w:hyperlink>
      </w:p>
      """)

    assert {:ok, [paragraph]} =
             Docx.from_xml(xml)

    assert paragraph.text ==
             "https://www.marymartin.com/web?pid=908614"
  end

  test "extracts paragraph styles" do
    xml =
      document_xml("""
      <w:p>
        <w:pPr>
          <w:pStyle w:val="Heading1"/>
        </w:pPr>
        <w:r>
          <w:t>History</w:t>
        </w:r>
      </w:p>

      <w:p>
        <w:pPr>
          <w:pStyle w:val="ListParagraph"/>
        </w:pPr>
        <w:r>
          <w:t>Brunei Darussalam – History.</w:t>
        </w:r>
      </w:p>
      """)

    assert {:ok, paragraphs} =
             Docx.from_xml(xml)

    assert [
             %Paragraph{
               style: "Heading1",
               text: "History"
             },
             %Paragraph{
               style: "ListParagraph",
               text: "Brunei Darussalam – History."
             }
           ] = paragraphs
  end

  test "preserves Unicode exactly" do
    text =
      "Pāṇini / Tiếng Việt / العربية / جاوي / မြန်မာစာ / 中文"

    xml =
      document_xml("""
      <w:p>
        <w:r>
          <w:t>#{text}</w:t>
        </w:r>
      </w:p>
      """)

    assert {:ok, [paragraph]} =
             Docx.from_xml(xml)

    assert paragraph.text == text
  end

  test "keeps empty paragraphs because paragraph position is source information" do
    xml =
      document_xml("""
      <w:p>
        <w:r>
          <w:t>Before</w:t>
        </w:r>
      </w:p>

      <w:p/>

      <w:p>
        <w:r>
          <w:t>After</w:t>
        </w:r>
      </w:p>
      """)

    assert {:ok, paragraphs} =
             Docx.from_xml(xml)

    assert Enum.map(paragraphs, & &1.text) == [
             "Before",
             "",
             "After"
           ]

    assert Enum.map(paragraphs, & &1.index) == [
             1,
             2,
             3
           ]
  end

  test "returns an error for malformed XML" do
    assert {:error, {:invalid_docx_xml, _reason}} =
             Docx.from_xml("<not valid")
  end

  defp document_xml(body) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <w:document
      xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
      xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    >
      <w:body>
        #{body}
      </w:body>
    </w:document>
    """
  end

  test "preserves manual line breaks inside a Word paragraph" do
    xml =
      document_xml("""
      <w:p>
        <w:r>
          <w:t>Indonesia : Histokultura 2025</w:t>
          <w:br/>
          <w:t>X+82 p</w:t>
          <w:br/>
          <w:t>Arts</w:t>
          <w:br/>
          <w:t>9786237554554</w:t>
          <w:br/>
          <w:t>USD : 12.40 / PB</w:t>
          <w:br/>
          <w:t>121 gm.</w:t>
        </w:r>
      </w:p>
      """)

    assert {:ok, [paragraph]} =
             Docx.from_xml(xml)

    assert paragraph.text ==
             "Indonesia : Histokultura 2025\n" <>
               "X+82 p\n" <>
               "Arts\n" <>
               "9786237554554\n" <>
               "USD : 12.40 / PB\n" <>
               "121 gm."
  end

  test "preserves tabs inside a Word paragraph" do
    xml =
      document_xml("""
      <w:p>
        <w:r>
          <w:t>Before</w:t>
          <w:tab/>
          <w:t>After</w:t>
        </w:r>
      </w:p>
      """)

    assert {:ok, [paragraph]} =
             Docx.from_xml(xml)

    assert paragraph.text == "Before\tAfter"
  end
end
