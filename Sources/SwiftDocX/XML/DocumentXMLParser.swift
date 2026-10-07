import Foundation

/// Error types for XML parsing
public enum DocumentXMLParserError: Error, LocalizedError {
    case invalidXML(String)
    case missingElement(String)
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidXML(let detail):
            return "Invalid XML: \(detail)"
        case .missingElement(let element):
            return "Missing required element: \(element)"
        case .parsingFailed(let detail):
            return "Parsing failed: \(detail)"
        }
    }
}

/// Parses Word document XML content
public class DocumentXMLParser {

    public init() {}

    /// Parses document.xml content and returns paragraphs
    public func parseDocumentXML(_ xmlData: Data) throws -> [Paragraph] {
        let parsedRoot: XMLTreeElement?
        do {
            parsedRoot = try XMLTreeBuilder.parse(xmlData)
        } catch {
            throw DocumentXMLParserError.invalidXML(error.localizedDescription)
        }

        guard let root = parsedRoot else {
            throw DocumentXMLParserError.missingElement("document root")
        }

        // Find body element
        guard let body = findElement(in: root, localName: "body") else {
            throw DocumentXMLParserError.missingElement("body")
        }

        var paragraphs: [Paragraph] = []

        // Parse all paragraph elements
        for element in body.children {
            guard element.localName == "p" else { continue }

            let paragraph = try parseParagraph(element)
            paragraphs.append(paragraph)
        }

        return paragraphs
    }

    private func parseParagraph(_ element: XMLTreeElement) throws -> Paragraph {
        let paragraph = Paragraph()

        // Parse paragraph properties
        if let pPr = findElement(in: element, localName: "pPr") {
            // Alignment
            if let jc = findElement(in: pPr, localName: "jc"),
               let val = getAttributeValue(jc, localName: "val") {
                paragraph.alignment = ParagraphAlignment(rawValue: val)
            }

            // Spacing
            if let spacing = findElement(in: pPr, localName: "spacing") {
                var paragraphSpacing = ParagraphSpacing()
                if let before = getAttributeValue(spacing, localName: "before"),
                   let beforeVal = Int(before) {
                    paragraphSpacing.before = Double(beforeVal) / 20.0  // Twips to points
                }
                if let after = getAttributeValue(spacing, localName: "after"),
                   let afterVal = Int(after) {
                    paragraphSpacing.after = Double(afterVal) / 20.0
                }
                if let line = getAttributeValue(spacing, localName: "line"),
                   let lineVal = Int(line) {
                    paragraphSpacing.lineSpacing = Double(lineVal) / 240.0
                }
                paragraph.spacing = paragraphSpacing
            }

            // Indentation
            if let ind = findElement(in: pPr, localName: "ind") {
                var indentation = ParagraphIndentation()
                if let left = getAttributeValue(ind, localName: "left"),
                   let leftVal = Int(left) {
                    indentation.left = Double(leftVal) / 20.0
                }
                if let right = getAttributeValue(ind, localName: "right"),
                   let rightVal = Int(right) {
                    indentation.right = Double(rightVal) / 20.0
                }
                if let firstLine = getAttributeValue(ind, localName: "firstLine"),
                   let firstLineVal = Int(firstLine) {
                    indentation.firstLine = Double(firstLineVal) / 20.0
                }
                if let hanging = getAttributeValue(ind, localName: "hanging"),
                   let hangingVal = Int(hanging) {
                    indentation.firstLine = -Double(hangingVal) / 20.0
                }
                paragraph.indentation = indentation
            }
        }

        // Parse runs
        for runElement in element.children {
            guard runElement.localName == "r" else { continue }

            let run = try parseRun(runElement)
            paragraph.runs.append(run)
        }

        return paragraph
    }

    private func parseRun(_ element: XMLTreeElement) throws -> Run {
        var text = ""
        var formatting = TextFormatting()

        // Parse run properties
        if let rPr = findElement(in: element, localName: "rPr") {
            formatting = parseRunProperties(rPr)
        }

        // Parse text content
        for textElement in element.children {
            guard textElement.localName == "t" else { continue }

            text += textElement.stringValue
        }

        return Run(text: text, formatting: formatting)
    }

    private func parseRunProperties(_ element: XMLTreeElement) -> TextFormatting {
        var formatting = TextFormatting()

        for propElement in element.children {
            switch propElement.localName {
            case "b":
                // Check if explicitly set to false
                if let val = getAttributeValue(propElement, localName: "val"), val == "0" || val == "false" {
                    formatting.bold = false
                } else {
                    formatting.bold = true
                }

            case "i":
                if let val = getAttributeValue(propElement, localName: "val"), val == "0" || val == "false" {
                    formatting.italic = false
                } else {
                    formatting.italic = true
                }

            case "u":
                if let val = getAttributeValue(propElement, localName: "val") {
                    if val != "none" {
                        formatting.underline = UnderlineStyle(rawValue: val) ?? .single
                    }
                } else {
                    formatting.underline = .single
                }

            case "strike":
                if let val = getAttributeValue(propElement, localName: "val"), val == "0" || val == "false" {
                    formatting.strikethrough = false
                } else {
                    formatting.strikethrough = true
                }

            case "color":
                if let val = getAttributeValue(propElement, localName: "val"),
                   val != "auto" {
                    formatting.color = Color(hex: val)
                }

            case "highlight":
                if let val = getAttributeValue(propElement, localName: "val") {
                    formatting.highlight = HighlightColor(rawValue: val)
                }

            case "rFonts":
                if let ascii = getAttributeValue(propElement, localName: "ascii") {
                    formatting.font = Font(name: ascii)
                }

            case "sz":
                if let val = getAttributeValue(propElement, localName: "val"),
                   let halfPoints = Int(val) {
                    formatting.fontSize = Double(halfPoints) / 2.0
                }

            case "caps":
                if let val = getAttributeValue(propElement, localName: "val"), val == "0" || val == "false" {
                    formatting.allCaps = false
                } else {
                    formatting.allCaps = true
                }

            case "smallCaps":
                if let val = getAttributeValue(propElement, localName: "val"), val == "0" || val == "false" {
                    formatting.smallCaps = false
                } else {
                    formatting.smallCaps = true
                }

            case "vertAlign":
                if let val = getAttributeValue(propElement, localName: "val") {
                    if val == "superscript" {
                        formatting.superscript = true
                    } else if val == "subscript" {
                        formatting.subscriptText = true
                    }
                }

            default:
                break
            }
        }

        return formatting
    }

    // MARK: - Helpers

    private func findElement(in parent: XMLTreeElement, localName: String) -> XMLTreeElement? {
        return parent.children.first { $0.localName == localName }
    }

    private func getAttributeValue(_ element: XMLTreeElement, localName: String) -> String? {
        // Try with namespace prefix first
        if let value = element.attributes["w:\(localName)"] {
            return value
        }
        // Try without prefix
        return element.attributes[localName]
    }
}
