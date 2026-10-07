import XCTest
@testable import SwiftDocX

final class SwiftDocXTests: XCTestCase {

    // MARK: - Document Tests

    func testCreateEmptyDocument() {
        let doc = Document()
        XCTAssertTrue(doc.isEmpty)
        XCTAssertEqual(doc.paragraphCount, 0)
    }

    func testAddSimpleParagraph() {
        let doc = Document()
        doc.addParagraph("Hello, World!")

        XCTAssertEqual(doc.paragraphCount, 1)
        XCTAssertEqual(doc.text, "Hello, World!")
    }

    func testAddMultipleParagraphs() {
        let doc = Document()
        doc.addParagraph("First paragraph")
        doc.addParagraph("Second paragraph")
        doc.addParagraph("Third paragraph")

        XCTAssertEqual(doc.paragraphCount, 3)
        XCTAssertEqual(doc.paragraphs[0].text, "First paragraph")
        XCTAssertEqual(doc.paragraphs[1].text, "Second paragraph")
        XCTAssertEqual(doc.paragraphs[2].text, "Third paragraph")
    }

    func testClearDocument() {
        let doc = Document()
        doc.addParagraph("Test")
        doc.clear()

        XCTAssertTrue(doc.isEmpty)
    }

    // MARK: - Paragraph Tests

    func testCreateParagraphWithText() {
        let para = Paragraph("Test text")
        XCTAssertEqual(para.text, "Test text")
        XCTAssertEqual(para.runs.count, 1)
    }

    func testAddMultipleRuns() {
        let para = Paragraph()
        para.addRun("Bold text", formatting: TextFormatting(bold: true))
        para.addRun(" and ")
        para.addRun("italic", formatting: TextFormatting(italic: true))

        XCTAssertEqual(para.runs.count, 3)
        XCTAssertEqual(para.text, "Bold text and italic")
    }

    func testParagraphAlignment() {
        let para = Paragraph("Centered text")
        para.alignment = .center

        XCTAssertEqual(para.alignment, .center)
    }

    // MARK: - TextFormatting Tests

    func testTextFormattingDefaults() {
        let formatting = TextFormatting()
        XCTAssertFalse(formatting.bold)
        XCTAssertFalse(formatting.italic)
        XCTAssertNil(formatting.underline)
        XCTAssertFalse(formatting.strikethrough)
        XCTAssertNil(formatting.font)
        XCTAssertNil(formatting.color)
        XCTAssertNil(formatting.fontSize)
        XCTAssertTrue(formatting.isEmpty)
    }

    func testTextFormattingWithValues() {
        let formatting = TextFormatting(
            bold: true,
            italic: true,
            underline: .single,
            strikethrough: false,
            font: .arial,
            color: .red,
            fontSize: 14
        )

        XCTAssertTrue(formatting.bold)
        XCTAssertTrue(formatting.italic)
        XCTAssertEqual(formatting.underline, .single)
        XCTAssertFalse(formatting.strikethrough)
        XCTAssertEqual(formatting.font?.name, "Arial")
        XCTAssertEqual(formatting.color, .red)
        XCTAssertEqual(formatting.fontSize, 14)
        XCTAssertFalse(formatting.isEmpty)
    }

    // MARK: - Color Tests

    func testColorFromRGB() {
        let color = Color(red: 255, green: 128, blue: 0)
        XCTAssertEqual(color.red, 255)
        XCTAssertEqual(color.green, 128)
        XCTAssertEqual(color.blue, 0)
    }

    func testColorFromHex() {
        let color = Color(hex: "FF8000")
        XCTAssertNotNil(color)
        XCTAssertEqual(color?.red, 255)
        XCTAssertEqual(color?.green, 128)
        XCTAssertEqual(color?.blue, 0)
    }

    func testColorToHex() {
        let color = Color(red: 255, green: 128, blue: 0)
        XCTAssertEqual(color.hexString, "FF8000")
    }

    func testPredefinedColors() {
        XCTAssertEqual(Color.red.hexString, "FF0000")
        XCTAssertEqual(Color.green.hexString, "008000")
        XCTAssertEqual(Color.blue.hexString, "0000FF")
        XCTAssertEqual(Color.black.hexString, "000000")
        XCTAssertEqual(Color.white.hexString, "FFFFFF")
    }

    // MARK: - Font Tests

    func testFontCreation() {
        let font = Font(name: "Georgia")
        XCTAssertEqual(font.name, "Georgia")
    }

    func testPredefinedFonts() {
        XCTAssertEqual(Font.arial.name, "Arial")
        XCTAssertEqual(Font.timesNewRoman.name, "Times New Roman")
        XCTAssertEqual(Font.calibri.name, "Calibri")
    }

    // MARK: - Run Tests

    func testRunCreation() {
        let run = Run("Test text")
        XCTAssertEqual(run.text, "Test text")
        XCTAssertTrue(run.formatting.isEmpty)
    }

    func testRunWithFormatting() {
        let run = Run(text: "Bold text", formatting: TextFormatting(bold: true))
        XCTAssertEqual(run.text, "Bold text")
        XCTAssertTrue(run.formatting.bold)
    }

    // MARK: - Write/Read Integration Tests

    func testWriteAndReadDocument() throws {
        // Create a document
        let doc = Document()
        doc.addParagraph("Hello, World!")

        let para = doc.addParagraph()
        para.addRun("Bold", formatting: TextFormatting(bold: true))
        para.addRun(" and ")
        para.addRun("Italic", formatting: TextFormatting(italic: true))

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try doc.write(to: tempURL)

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        // Read it back
        let readDoc = try Document(contentsOf: tempURL)

        // Verify content
        XCTAssertEqual(readDoc.paragraphCount, 2)
        XCTAssertEqual(readDoc.paragraphs[0].text, "Hello, World!")
        XCTAssertEqual(readDoc.paragraphs[1].text, "Bold and Italic")

        // Verify formatting
        XCTAssertTrue(readDoc.paragraphs[1].runs[0].formatting.bold)
        XCTAssertTrue(readDoc.paragraphs[1].runs[2].formatting.italic)
    }

    func testWriteDocumentWithFormatting() throws {
        let doc = Document()

        // Add paragraph with various formatting
        let para = doc.addParagraph()
        para.addRun("Red text", formatting: TextFormatting(color: .red))
        para.addRun(" ")
        para.addRun("Arial 16pt", formatting: TextFormatting(font: .arial, fontSize: 16))
        para.addRun(" ")
        para.addRun("Underlined", formatting: TextFormatting(underline: .single))

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_formatted_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try doc.write(to: tempURL)

        // Verify file exists and is non-empty
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0)
    }

    func testWriteDocumentWithParagraphProperties() throws {
        let doc = Document()

        let para = doc.addParagraph("Centered paragraph")
        para.alignment = .center
        para.spacing = ParagraphSpacing(before: 12, after: 12, lineSpacing: 1.5)
        para.indentation = ParagraphIndentation(left: 36)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_para_\(UUID().uuidString).docx")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try doc.write(to: tempURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        // Read back and verify
        let readDoc = try Document(contentsOf: tempURL)
        XCTAssertEqual(readDoc.paragraphs[0].alignment, .center)
    }

    // MARK: - XML Parsing Tests

    func testParseDocumentXMLFromWord() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>
        <w:p>
        <w:pPr><w:jc w:val="center"/></w:pPr>
        <w:r><w:rPr><w:b/><w:sz w:val="28"/></w:rPr><w:t xml:space="preserve">Tom &amp; </w:t></w:r>
        <w:r><w:t xml:space="preserve"> </w:t></w:r>
        <w:r><w:rPr><w:b w:val="0"/></w:rPr><w:t>Jerry</w:t></w:r>
        </w:p>
        <w:sectPr/>
        </w:body>
        </w:document>
        """

        let paragraphs = try DocumentXMLParser().parseDocumentXML(Data(xml.utf8))

        XCTAssertEqual(paragraphs.count, 1)
        XCTAssertEqual(paragraphs[0].alignment, .center)
        XCTAssertEqual(paragraphs[0].runs.count, 3)
        XCTAssertEqual(paragraphs[0].text, "Tom &  Jerry")
        XCTAssertTrue(paragraphs[0].runs[0].formatting.bold)
        XCTAssertEqual(paragraphs[0].runs[0].formatting.fontSize, 14)
        XCTAssertFalse(paragraphs[0].runs[2].formatting.bold)
    }

    func testParseInvalidXMLThrows() {
        XCTAssertThrowsError(try DocumentXMLParser().parseDocumentXML(Data("<w:document><w:body>".utf8)))
    }
}
