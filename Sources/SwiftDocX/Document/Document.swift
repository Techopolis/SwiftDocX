import Foundation

/// Error types for document operations
public enum DocumentError: Error, LocalizedError {
    case readFailed(String)
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .readFailed(let detail):
            return "Failed to read document: \(detail)"
        case .writeFailed(let detail):
            return "Failed to write document: \(detail)"
        }
    }
}

/// Document element that can be a paragraph or table
public enum DocumentElement {
    case paragraph(Paragraph)
    case table(Table)
}

/// Document properties for metadata and accessibility
public struct DocumentProperties: Sendable {
    /// Document title (accessibility)
    public var title: String?

    /// Document subject
    public var subject: String?

    /// Document author
    public var author: String?

    /// Document keywords
    public var keywords: String?

    /// Document description
    public var description: String?

    /// Document language (e.g., "en-US", "es-ES")
    public var language: String?

    public init(
        title: String? = nil,
        subject: String? = nil,
        author: String? = nil,
        keywords: String? = nil,
        description: String? = nil,
        language: String? = nil
    ) {
        self.title = title
        self.subject = subject
        self.author = author
        self.keywords = keywords
        self.description = description
        self.language = language
    }
}

/// Represents a Word document (.docx file)
public class Document {
    /// The paragraphs in the document
    public var paragraphs: [Paragraph]

    /// The tables in the document
    public var tables: [Table]

    /// All elements in document order
    public var elements: [DocumentElement]

    /// Document properties (metadata and accessibility)
    public var properties: DocumentProperties

    /// Page size and margins
    public var pageAttributes: PageAttributes

    /// Document header (appears at top of pages)
    public var header: Header?

    /// Document footer (appears at bottom of pages)
    public var footer: Footer?

    /// Creates an empty document
    public init() {
        self.paragraphs = []
        self.tables = []
        self.elements = []
        self.properties = DocumentProperties()
        self.pageAttributes = PageAttributes()
        self.header = nil
        self.footer = nil
    }

    /// Creates a document by reading from a .docx file
    /// - Parameter url: URL to the .docx file
    public convenience init(contentsOf url: URL) throws {
        self.init()
        let reader = DocumentReader()
        do {
            self.paragraphs = try reader.read(from: url)
        } catch {
            throw DocumentError.readFailed(error.localizedDescription)
        }
    }

    /// Writes the document to a .docx file
    /// - Parameter url: Destination URL for the .docx file
    public func write(to url: URL) throws {
        let writer = DocumentWriter()
        do {
            try writer.write(document: self, to: url)
        } catch {
            throw DocumentError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Paragraph Methods

    /// Adds a paragraph with the specified text
    @discardableResult
    public func addParagraph(_ text: String, formatting: TextFormatting = .none) -> Paragraph {
        let paragraph = Paragraph(text, formatting: formatting)
        paragraphs.append(paragraph)
        elements.append(.paragraph(paragraph))
        return paragraph
    }

    /// Adds an empty paragraph
    @discardableResult
    public func addParagraph() -> Paragraph {
        let paragraph = Paragraph()
        paragraphs.append(paragraph)
        elements.append(.paragraph(paragraph))
        return paragraph
    }

    // MARK: - Heading Methods

    /// Adds a heading with the specified level
    @discardableResult
    public func addHeading(_ text: String, level: HeadingLevel, formatting: TextFormatting = .none) -> Paragraph {
        let paragraph = Paragraph(text, formatting: formatting)
        paragraph.headingLevel = level
        paragraphs.append(paragraph)
        elements.append(.paragraph(paragraph))
        return paragraph
    }

    /// Adds a Heading 1
    @discardableResult
    public func addHeading1(_ text: String) -> Paragraph {
        addHeading(text, level: .heading1)
    }

    /// Adds a Heading 2
    @discardableResult
    public func addHeading2(_ text: String) -> Paragraph {
        addHeading(text, level: .heading2)
    }

    /// Adds a Heading 3
    @discardableResult
    public func addHeading3(_ text: String) -> Paragraph {
        addHeading(text, level: .heading3)
    }

    // MARK: - List Methods

    /// Adds a bullet list item
    @discardableResult
    public func addBulletItem(_ text: String, level: Int = 0, formatting: TextFormatting = .none) -> Paragraph {
        let paragraph = Paragraph(text, formatting: formatting)
        paragraph.listType = .bullet
        paragraph.listLevel = level
        paragraphs.append(paragraph)
        elements.append(.paragraph(paragraph))
        return paragraph
    }

    /// Adds multiple bullet items at once
    public func addBulletList(_ items: [String]) {
        for item in items {
            addBulletItem(item)
        }
    }

    /// Adds a numbered list item
    @discardableResult
    public func addNumberedItem(_ text: String, level: Int = 0, formatting: TextFormatting = .none) -> Paragraph {
        let paragraph = Paragraph(text, formatting: formatting)
        paragraph.listType = .numbered
        paragraph.listLevel = level
        paragraphs.append(paragraph)
        elements.append(.paragraph(paragraph))
        return paragraph
    }

    /// Adds multiple numbered items at once
    public func addNumberedList(_ items: [String]) {
        for item in items {
            addNumberedItem(item)
        }
    }

    // MARK: - Table Methods

    /// Adds a table with the specified rows and columns
    @discardableResult
    public func addTable(rows: Int, columns: Int) -> Table {
        let table = Table(rows: rows, columns: columns)
        tables.append(table)
        elements.append(.table(table))
        return table
    }

    /// Adds an existing table
    @discardableResult
    public func addTable(_ table: Table) -> Table {
        tables.append(table)
        elements.append(.table(table))
        return table
    }

    /// Creates a table from a 2D array of strings
    @discardableResult
    public func addTable(from data: [[String]], hasHeader: Bool = false) -> Table {
        let table = Table()
        for (rowIndex, rowData) in data.enumerated() {
            let row = table.addRow()
            if hasHeader && rowIndex == 0 {
                row.isHeader = true
            }
            for cellText in rowData {
                row.addCell(cellText)
            }
        }
        tables.append(table)
        elements.append(.table(table))
        return table
    }

    // MARK: - Page Break

    /// Adds a page break
    public func addPageBreak() {
        let para = Paragraph()
        para.pageBreakBefore = true
        paragraphs.append(para)
        elements.append(.paragraph(para))
    }

    // MARK: - Hyperlink Methods

    /// Adds a hyperlink as its own paragraph
    @discardableResult
    public func addHyperlink(url: String, text: String, tooltip: String? = nil) -> Paragraph {
        let para = Paragraph()
        para.addHyperlink(url: url, text: text, tooltip: tooltip)
        paragraphs.append(para)
        elements.append(.paragraph(para))
        return para
    }

    // MARK: - Image Methods

    /// Adds an image as its own paragraph
    @discardableResult
    public func addImage(_ image: DocImage) -> Paragraph {
        let para = Paragraph()
        para.addImage(image)
        paragraphs.append(para)
        elements.append(.paragraph(para))
        return para
    }

    /// Adds an image from file URL
    @discardableResult
    public func addImage(contentsOf url: URL, width: Double? = nil, height: Double? = nil, altText: String? = nil) -> Paragraph? {
        guard let image = DocImage(contentsOf: url, width: width, height: height) else { return nil }
        image.altText = altText
        return addImage(image)
    }

    // MARK: - Header/Footer Methods

    /// Creates and returns a header for the document
    @discardableResult
    public func createHeader() -> Header {
        let header = Header()
        self.header = header
        return header
    }

    /// Creates and returns a footer for the document
    @discardableResult
    public func createFooter() -> Footer {
        let footer = Footer()
        self.footer = footer
        return footer
    }

    /// Convenience: Adds a simple text header
    @discardableResult
    public func setHeader(_ text: String, alignment: ParagraphAlignment = .center) -> Header {
        let header = createHeader()
        let para = header.addParagraph(text)
        para.alignment = alignment
        return header
    }

    /// Convenience: Adds a simple text footer
    @discardableResult
    public func setFooter(_ text: String, alignment: ParagraphAlignment = .center) -> Footer {
        let footer = createFooter()
        let para = footer.addParagraph(text)
        para.alignment = alignment
        return footer
    }

    /// Convenience: Adds a footer with page numbers
    @discardableResult
    public func setFooterWithPageNumbers(alignment: ParagraphAlignment = .center) -> Footer {
        let footer = createFooter()
        footer.addPageNumber(alignment: alignment)
        return footer
    }

    /// Convenience: Adds a footer with "Page X of Y" format
    @discardableResult
    public func setFooterWithPageNumbersAndTotal(alignment: ParagraphAlignment = .center) -> Footer {
        let footer = createFooter()
        footer.addPageNumberWithTotal(alignment: alignment)
        return footer
    }

    // MARK: - Properties

    /// Returns the full text of the document (all paragraphs joined with newlines)
    public var text: String {
        paragraphs.map { $0.text }.joined(separator: "\n")
    }

    /// Returns true if the document has no content
    public var isEmpty: Bool {
        elements.isEmpty
    }

    /// Number of paragraphs in the document
    public var paragraphCount: Int {
        paragraphs.count
    }

    /// Number of tables in the document
    public var tableCount: Int {
        tables.count
    }

    /// Removes all content from the document
    public func clear() {
        paragraphs.removeAll()
        tables.removeAll()
        elements.removeAll()
        header = nil
        footer = nil
    }
}

extension Document: CustomStringConvertible {
    public var description: String {
        "Document(paragraphs: \(paragraphs.count))"
    }
}
