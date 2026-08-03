import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

/// Builds XML content for Word documents
public class DocumentXMLBuilder {

    public init() {}

    /// Builds the main document.xml content from document elements
    public func buildDocumentXML(elements: [DocumentElement]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="\(XMLNamespaces.wordprocessingML)" xmlns:r="\(XMLNamespaces.relationships)">
        <w:body>
        """

        for element in elements {
            switch element {
            case .paragraph(let paragraph):
                xml += buildParagraph(paragraph)
            case .table(let table):
                xml += buildTable(table)
            }
        }

        // Add section properties (required for valid document)
        xml += """
        <w:sectPr>
        <w:pgSz w:w="12240" w:h="15840"/>
        <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
        </w:sectPr>
        """

        xml += """
        </w:body>
        </w:document>
        """

        return xml
    }

    /// Legacy method for backward compatibility
    public func buildDocumentXML(paragraphs: [Paragraph]) -> String {
        let elements = paragraphs.map { DocumentElement.paragraph($0) }
        return buildDocumentXML(elements: elements)
    }

    // MARK: - Paragraph Building

    private func buildParagraph(_ paragraph: Paragraph) -> String {
        var xml = "<w:p>"

        // Paragraph properties
        let hasParagraphProps = paragraph.alignment != nil ||
            paragraph.spacing != .none ||
            paragraph.indentation != .none ||
            paragraph.headingLevel != nil ||
            paragraph.listType != nil ||
            paragraph.pageBreakBefore

        if hasParagraphProps {
            xml += "<w:pPr>"

            // Page break before
            if paragraph.pageBreakBefore {
                xml += "<w:pageBreakBefore/>"
            }

            // Style reference for headings
            if let heading = paragraph.headingLevel {
                xml += "<w:pStyle w:val=\"\(heading.styleId)\"/>"
            }

            // Numbering for lists
            if let listType = paragraph.listType {
                let numId = listType == .bullet ? 1 : 2
                xml += "<w:numPr>"
                xml += "<w:ilvl w:val=\"\(paragraph.listLevel)\"/>"
                xml += "<w:numId w:val=\"\(numId)\"/>"
                xml += "</w:numPr>"
            }

            if let alignment = paragraph.alignment {
                xml += "<w:jc w:val=\"\(alignment.rawValue)\"/>"
            }

            if paragraph.spacing != .none {
                var spacingAttrs = ""
                if let before = paragraph.spacing.before {
                    spacingAttrs += " w:before=\"\(Int(before * 20))\""
                }
                if let after = paragraph.spacing.after {
                    spacingAttrs += " w:after=\"\(Int(after * 20))\""
                }
                if let lineSpacing = paragraph.spacing.lineSpacing {
                    spacingAttrs += " w:line=\"\(Int(lineSpacing * 240))\" w:lineRule=\"auto\""
                }
                if !spacingAttrs.isEmpty {
                    xml += "<w:spacing\(spacingAttrs)/>"
                }
            }

            if paragraph.indentation != .none {
                var indentAttrs = ""
                if let left = paragraph.indentation.left {
                    indentAttrs += " w:left=\"\(Int(left * 20))\""
                }
                if let right = paragraph.indentation.right {
                    indentAttrs += " w:right=\"\(Int(right * 20))\""
                }
                if let firstLine = paragraph.indentation.firstLine {
                    if firstLine >= 0 {
                        indentAttrs += " w:firstLine=\"\(Int(firstLine * 20))\""
                    } else {
                        indentAttrs += " w:hanging=\"\(Int(-firstLine * 20))\""
                    }
                }
                if !indentAttrs.isEmpty {
                    xml += "<w:ind\(indentAttrs)/>"
                }
            }

            xml += "</w:pPr>"
        }

        // Runs
        for run in paragraph.runs {
            xml += buildRun(run)
        }

        xml += "</w:p>"
        return xml
    }

    private func buildRun(_ run: Run, hyperlinkRelId: String? = nil) -> String {
        var xml = ""

        // Handle hyperlinks - wrap run in hyperlink element
        if let hyperlink = run.hyperlink, let relId = hyperlinkRelId {
            var hyperlinkAttrs = "r:id=\"\(relId)\""
            if let tooltip = hyperlink.tooltip {
                hyperlinkAttrs += " w:tooltip=\"\(escapeXMLAttribute(tooltip))\""
            }
            xml += "<w:hyperlink \(hyperlinkAttrs)>"
        }

        xml += "<w:r>"

        if !run.formatting.isEmpty {
            xml += "<w:rPr>"
            xml += buildRunProperties(run.formatting)
            xml += "</w:rPr>"
        }

        // Handle page number field
        if run.isPageNumberField {
            xml += "<w:fldChar w:fldCharType=\"begin\"/></w:r>"
            xml += "<w:r><w:instrText>PAGE</w:instrText></w:r>"
            xml += "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>"
            xml += "<w:r><w:t>1</w:t></w:r>"
            xml += "<w:r><w:fldChar w:fldCharType=\"end\"/>"
        }
        // Handle total pages field
        else if run.isTotalPagesField {
            xml += "<w:fldChar w:fldCharType=\"begin\"/></w:r>"
            xml += "<w:r><w:instrText>NUMPAGES</w:instrText></w:r>"
            xml += "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r>"
            xml += "<w:r><w:t>1</w:t></w:r>"
            xml += "<w:r><w:fldChar w:fldCharType=\"end\"/>"
        }
        // Handle image
        else if let image = run.image, let relId = image.relationshipId {
            xml += buildImageDrawing(image, relationshipId: relId)
        }
        // Normal text
        else {
            let escapedText = escapeXML(run.text)
            let needsPreserveSpace = run.text.hasPrefix(" ") || run.text.hasSuffix(" ") || run.text.contains("  ")
            if needsPreserveSpace {
                xml += "<w:t xml:space=\"preserve\">\(escapedText)</w:t>"
            } else {
                xml += "<w:t>\(escapedText)</w:t>"
            }
        }

        xml += "</w:r>"

        // Close hyperlink if needed
        if run.hyperlink != nil && hyperlinkRelId != nil {
            xml += "</w:hyperlink>"
        }

        return xml
    }

    private func buildImageDrawing(_ image: DocImage, relationshipId: String) -> String {
        // Default size if not specified (assume 300x300 pixels at 96 DPI = ~3.125 inches)
        let widthEmu = Int((image.width ?? 200) * 914400 / 72)  // Points to EMUs
        let heightEmu = Int((image.height ?? 200) * 914400 / 72)

        let altText = escapeXMLAttribute(image.altText ?? "Image")
        let title = escapeXMLAttribute(image.title ?? "")

        return """
        <w:drawing>
        <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="\(widthEmu)" cy="\(heightEmu)"/>
        <wp:docPr id="1" name="Picture" descr="\(altText)" title="\(title)"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:nvPicPr>
        <pic:cNvPr id="0" name="Picture" descr="\(altText)"/>
        <pic:cNvPicPr/>
        </pic:nvPicPr>
        <pic:blipFill>
        <a:blip r:embed="\(relationshipId)" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
        <a:stretch><a:fillRect/></a:stretch>
        </pic:blipFill>
        <pic:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="\(widthEmu)" cy="\(heightEmu)"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </pic:spPr>
        </pic:pic>
        </a:graphicData>
        </a:graphic>
        </wp:inline>
        </w:drawing>
        """
    }

    private func buildRunProperties(_ formatting: TextFormatting) -> String {
        var xml = ""

        if formatting.bold {
            xml += "<w:b/>"
        }
        if formatting.italic {
            xml += "<w:i/>"
        }
        if let underline = formatting.underline {
            xml += "<w:u w:val=\"\(underline.rawValue)\"/>"
        }
        if formatting.strikethrough {
            xml += "<w:strike/>"
        }
        if let font = formatting.font {
            let escapedName = escapeXMLAttribute(font.name)
            xml += "<w:rFonts w:ascii=\"\(escapedName)\" w:hAnsi=\"\(escapedName)\" w:cs=\"\(escapedName)\"/>"
        }
        if let fontSize = formatting.fontSize {
            let halfPoints = Int(fontSize * 2)
            xml += "<w:sz w:val=\"\(halfPoints)\"/>"
            xml += "<w:szCs w:val=\"\(halfPoints)\"/>"
        }
        if let color = formatting.color {
            xml += "<w:color w:val=\"\(color.hexString)\"/>"
        }
        if let highlight = formatting.highlight {
            xml += "<w:highlight w:val=\"\(highlight.rawValue)\"/>"
        }
        if formatting.allCaps {
            xml += "<w:caps/>"
        }
        if formatting.smallCaps {
            xml += "<w:smallCaps/>"
        }
        if formatting.superscript {
            xml += "<w:vertAlign w:val=\"superscript\"/>"
        } else if formatting.subscriptText {
            xml += "<w:vertAlign w:val=\"subscript\"/>"
        }

        return xml
    }

    // MARK: - Table Building

    /// Builds XML for a single table element
    public func buildTableXML(_ table: Table) -> String {
        return buildTable(table)
    }

    private func buildTable(_ table: Table) -> String {
        var xml = "<w:tbl>"

        // Table properties
        xml += "<w:tblPr>"
        xml += "<w:tblStyle w:val=\"TableGrid\"/>"
        xml += "<w:tblW w:w=\"0\" w:type=\"auto\"/>"

        // Table borders
        xml += buildTableBorders(table.borders)

        // Table alignment
        if let alignment = table.alignment {
            xml += "<w:jc w:val=\"\(alignment.rawValue)\"/>"
        }

        // Table cell margins
        if let margins = table.cellMargins {
            xml += "<w:tblCellMar>"
            xml += "<w:top w:w=\"\(Int(margins.top * 20.0))\" w:type=\"dxa\"/>"
            xml += "<w:start w:w=\"\(Int(margins.left * 20.0))\" w:type=\"dxa\"/>"
            xml += "<w:bottom w:w=\"\(Int(margins.bottom * 20.0))\" w:type=\"dxa\"/>"
            xml += "<w:end w:w=\"\(Int(margins.right * 20.0))\" w:type=\"dxa\"/>"
            xml += "</w:tblCellMar>"
        }

        // Accessibility: Caption (visible title) and Description (for screen readers)
        if let caption = table.accessibilityCaption {
            xml += "<w:tblCaption w:val=\"\(escapeXMLAttribute(caption))\"/>"
        }
        if let summary = table.accessibilitySummary {
            xml += "<w:tblDescription w:val=\"\(escapeXMLAttribute(summary))\"/>"
        }

        xml += "</w:tblPr>"

        // Table grid (column definitions)
        if !table.columnWidths.isEmpty {
            xml += "<w:tblGrid>"
            for width in table.columnWidths {
                if let w = width {
                    xml += "<w:gridCol w:w=\"\(Int(w * 20))\"/>"
                } else {
                    xml += "<w:gridCol/>"
                }
            }
            xml += "</w:tblGrid>"
        }

        // Table rows
        for row in table.rows {
            xml += buildTableRow(row)
        }

        xml += "</w:tbl>"
        return xml
    }

    private func buildTableBorders(_ borders: TableBorders) -> String {
        var xml = "<w:tblBorders>"

        if let top = borders.top {
            xml += buildBorder("top", top)
        }
        if let left = borders.left {
            xml += buildBorder("left", left)
        }
        if let bottom = borders.bottom {
            xml += buildBorder("bottom", bottom)
        }
        if let right = borders.right {
            xml += buildBorder("right", right)
        }
        if let insideH = borders.insideH {
            xml += buildBorder("insideH", insideH)
        }
        if let insideV = borders.insideV {
            xml += buildBorder("insideV", insideV)
        }

        xml += "</w:tblBorders>"
        return xml
    }

    private func buildBorder(_ name: String, _ border: Border) -> String {
        var attrs = "w:val=\"\(border.style.rawValue)\""
        attrs += " w:sz=\"\(Int(border.width * 8))\""  // Convert points to eighths of a point
        attrs += " w:space=\"0\""
        if let color = border.color {
            attrs += " w:color=\"\(color.hexString)\""
        } else {
            attrs += " w:color=\"auto\""
        }
        return "<w:\(name) \(attrs)/>"
    }

    private func buildTableRow(_ row: TableRow) -> String {
        var xml = "<w:tr>"

        // Row properties
        if row.height != nil || row.isHeader {
            xml += "<w:trPr>"
            if let height = row.height {
                xml += "<w:trHeight w:val=\"\(Int(height * 20))\"/>"
            }
            if row.isHeader {
                xml += "<w:tblHeader/>"
            }
            xml += "</w:trPr>"
        }

        // Cells - track column position to skip cells covered by columnSpan
        var currentCol = 0
        for (index, cell) in row.cells.enumerated() {
            // Skip this cell if it's covered by a previous cell's span
            if index < currentCol {
                continue
            }

            xml += buildTableCell(cell)
            currentCol = index + cell.columnSpan
        }

        xml += "</w:tr>"
        return xml
    }

    private func buildTableCell(_ cell: TableCell) -> String {
        var xml = "<w:tc>"

        // Cell properties
        xml += "<w:tcPr>"

        if let width = cell.width {
            xml += "<w:tcW w:w=\"\(Int(width * 20))\" w:type=\"dxa\"/>"
        } else {
            xml += "<w:tcW w:w=\"0\" w:type=\"auto\"/>"
        }

        if let margins = cell.margins {
            xml += "<w:tcMar>"
            xml += "<w:top w:w=\"\(Int(margins.top * 20.0))\" w:type=\"dxa\"/>"
            xml += "<w:start w:w=\"\(Int(margins.left * 20.0))\" w:type=\"dxa\"/>"
            xml += "<w:bottom w:w=\"\(Int(margins.bottom * 20.0))\" w:type=\"dxa\"/>"
            xml += "<w:end w:w=\"\(Int(margins.right * 20.0))\" w:type=\"dxa\"/>"
            xml += "</w:tcMar>"
        }

        if cell.columnSpan > 1 {
            xml += "<w:gridSpan w:val=\"\(cell.columnSpan)\"/>"
        }

        if let vAlign = cell.verticalAlignment {
            xml += "<w:vAlign w:val=\"\(vAlign.rawValue)\"/>"
        }

        if let bgColor = cell.backgroundColor {
            xml += "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(bgColor.hexString)\"/>"
        }

        if let borders = cell.borders {
            xml += "<w:tcBorders>"
            if let top = borders.top { xml += buildBorder("top", top) }
            if let left = borders.left { xml += buildBorder("left", left) }
            if let bottom = borders.bottom { xml += buildBorder("bottom", bottom) }
            if let right = borders.right { xml += buildBorder("right", right) }
            xml += "</w:tcBorders>"
        }

        xml += "</w:tcPr>"

        // Cell content (paragraphs)
        if cell.paragraphs.isEmpty {
            // Empty cell still needs a paragraph
            xml += "<w:p/>"
        } else {
            for para in cell.paragraphs {
                xml += buildParagraph(para)
            }
        }

        xml += "</w:tc>"
        return xml
    }

    // MARK: - Supporting XML Files

    /// Builds the [Content_Types].xml file
    public func buildContentTypesXML(hasNumbering: Bool = false) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="\(XMLNamespaces.contentTypes)">
        <Default Extension="rels" ContentType="\(XMLNamespaces.contentTypeRelationships)"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="\(XMLNamespaces.contentTypeDocument)"/>
        <Override PartName="/word/styles.xml" ContentType="\(XMLNamespaces.contentTypeStyles)"/>
        <Override PartName="/word/settings.xml" ContentType="\(XMLNamespaces.contentTypeSettings)"/>
        """

        if hasNumbering {
            xml += """
            <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
            """
        }

        xml += "</Types>"
        return xml
    }

    /// Builds the _rels/.rels file
    public func buildRootRelsXML() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="\(XMLNamespaces.relationshipDocument)" Target="word/document.xml"/>
        </Relationships>
        """
    }

    /// Builds the word/_rels/document.xml.rels file
    public func buildDocumentRelsXML(hasNumbering: Bool = false) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="\(XMLNamespaces.relationshipStyles)" Target="styles.xml"/>
        <Relationship Id="rId2" Type="\(XMLNamespaces.relationshipSettings)" Target="settings.xml"/>
        """

        if hasNumbering {
            xml += """
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
            """
        }

        xml += "</Relationships>"
        return xml
    }

    /// Builds styles.xml with heading styles
    public func buildStylesXML() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="\(XMLNamespaces.wordprocessingML)">
        <w:docDefaults>
        <w:rPrDefault>
        <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        </w:rPr>
        </w:rPrDefault>
        </w:docDefaults>
        <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
        <w:name w:val="Normal"/>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading1">
        <w:name w:val="heading 1"/>
        <w:basedOn w:val="Normal"/>
        <w:next w:val="Normal"/>
        <w:pPr><w:spacing w:before="240" w:after="60"/><w:outlineLvl w:val="0"/></w:pPr>
        <w:rPr><w:b/><w:sz w:val="48"/><w:szCs w:val="48"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading2">
        <w:name w:val="heading 2"/>
        <w:basedOn w:val="Normal"/>
        <w:next w:val="Normal"/>
        <w:pPr><w:spacing w:before="200" w:after="60"/><w:outlineLvl w:val="1"/></w:pPr>
        <w:rPr><w:b/><w:sz w:val="36"/><w:szCs w:val="36"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading3">
        <w:name w:val="heading 3"/>
        <w:basedOn w:val="Normal"/>
        <w:next w:val="Normal"/>
        <w:pPr><w:spacing w:before="200" w:after="60"/><w:outlineLvl w:val="2"/></w:pPr>
        <w:rPr><w:b/><w:sz w:val="28"/><w:szCs w:val="28"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading4">
        <w:name w:val="heading 4"/>
        <w:basedOn w:val="Normal"/>
        <w:next w:val="Normal"/>
        <w:pPr><w:spacing w:before="200" w:after="60"/><w:outlineLvl w:val="3"/></w:pPr>
        <w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading5">
        <w:name w:val="heading 5"/>
        <w:basedOn w:val="Normal"/>
        <w:next w:val="Normal"/>
        <w:pPr><w:spacing w:before="200" w:after="60"/><w:outlineLvl w:val="4"/></w:pPr>
        <w:rPr><w:b/><w:i/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading6">
        <w:name w:val="heading 6"/>
        <w:basedOn w:val="Normal"/>
        <w:next w:val="Normal"/>
        <w:pPr><w:spacing w:before="200" w:after="60"/><w:outlineLvl w:val="5"/></w:pPr>
        <w:rPr><w:i/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
        </w:style>
        <w:style w:type="table" w:styleId="TableGrid">
        <w:name w:val="Table Grid"/>
        <w:tblPr>
        <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        </w:tblBorders>
        </w:tblPr>
        </w:style>
        </w:styles>
        """
    }

    /// Builds numbering.xml for lists
    public func buildNumberingXML() -> String {
        // Word uses specific character codes for bullets:
        // Level 0: Solid disc (Symbol font, char F0B7)
        // Level 1: Circle/ring (Courier New "o")
        // Level 2: Square (Wingdings font, char F0A7)
        // Level 3+: Alternating patterns
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:numbering xmlns:w="\(XMLNamespaces.wordprocessingML)">
        <w:abstractNum w:abstractNumId="0">
        <w:lvl w:ilvl="0">
        <w:start w:val="1"/><w:numFmt w:val="bullet"/>
        <w:lvlText w:val="\u{F0B7}"/>
        <w:lvlJc w:val="left"/>
        <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>
        </w:lvl>
        <w:lvl w:ilvl="1">
        <w:start w:val="1"/><w:numFmt w:val="bullet"/>
        <w:lvlText w:val="o"/>
        <w:lvlJc w:val="left"/>
        <w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New" w:cs="Courier New" w:hint="default"/></w:rPr>
        </w:lvl>
        <w:lvl w:ilvl="2">
        <w:start w:val="1"/><w:numFmt w:val="bullet"/>
        <w:lvlText w:val="\u{F0A7}"/>
        <w:lvlJc w:val="left"/>
        <w:pPr><w:ind w:left="2160" w:hanging="360"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Wingdings" w:hAnsi="Wingdings" w:hint="default"/></w:rPr>
        </w:lvl>
        <w:lvl w:ilvl="3">
        <w:start w:val="1"/><w:numFmt w:val="bullet"/>
        <w:lvlText w:val="\u{F0B7}"/>
        <w:lvlJc w:val="left"/>
        <w:pPr><w:ind w:left="2880" w:hanging="360"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>
        </w:lvl>
        <w:lvl w:ilvl="4">
        <w:start w:val="1"/><w:numFmt w:val="bullet"/>
        <w:lvlText w:val="o"/>
        <w:lvlJc w:val="left"/>
        <w:pPr><w:ind w:left="3600" w:hanging="360"/></w:pPr>
        <w:rPr><w:rFonts w:ascii="Courier New" w:hAnsi="Courier New" w:cs="Courier New" w:hint="default"/></w:rPr>
        </w:lvl>
        </w:abstractNum>
        <w:abstractNum w:abstractNumId="1">
        <w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl>
        <w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/><w:lvlText w:val="%2."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr></w:lvl>
        <w:lvl w:ilvl="2"><w:start w:val="1"/><w:numFmt w:val="lowerRoman"/><w:lvlText w:val="%3."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="2160" w:hanging="360"/></w:pPr></w:lvl>
        <w:lvl w:ilvl="3"><w:start w:val="1"/><w:numFmt w:val="decimal"/><w:lvlText w:val="%4."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="2880" w:hanging="360"/></w:pPr></w:lvl>
        <w:lvl w:ilvl="4"><w:start w:val="1"/><w:numFmt w:val="lowerLetter"/><w:lvlText w:val="%5."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="3600" w:hanging="360"/></w:pPr></w:lvl>
        </w:abstractNum>
        <w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>
        <w:num w:numId="2"><w:abstractNumId w:val="1"/></w:num>
        </w:numbering>
        """
    }

    /// Builds header XML file
    public func buildHeaderXML(_ header: Header) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="\(XMLNamespaces.wordprocessingML)" xmlns:r="\(XMLNamespaces.relationships)">
        """

        for para in header.paragraphs {
            xml += buildParagraph(para)
        }

        xml += "</w:hdr>"
        return xml
    }

    /// Builds footer XML file
    public func buildFooterXML(_ footer: Footer) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="\(XMLNamespaces.wordprocessingML)" xmlns:r="\(XMLNamespaces.relationships)">
        """

        for para in footer.paragraphs {
            xml += buildParagraph(para)
        }

        xml += "</w:ftr>"
        return xml
    }

    /// Builds a minimal settings.xml file
    public func buildSettingsXML() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:settings xmlns:w="\(XMLNamespaces.wordprocessingML)">
        <w:defaultTabStop w:val="720"/>
        </w:settings>
        """
    }

    // MARK: - Helpers

    private func escapeXML(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }

    private func escapeXMLAttribute(_ string: String) -> String {
        var result = escapeXML(string)
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }
}
