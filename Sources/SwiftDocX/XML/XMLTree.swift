import Foundation

#if canImport(FoundationXML)
import FoundationXML
#endif

/// A lightweight XML element tree.
///
/// `XMLDocument` and `XMLElement` are only available on macOS, so the parser
/// builds this tree with `XMLParser`, which is available on every platform.
final class XMLTreeElement {
    /// Qualified element name, for example `w:p`
    let name: String
    /// Attributes keyed by their qualified name, for example `w:val`
    let attributes: [String: String]
    private(set) var children: [XMLTreeElement] = []
    private var text = ""

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    /// Element name without its namespace prefix
    var localName: String {
        guard let colon = name.lastIndex(of: ":") else { return name }
        return String(name[name.index(after: colon)...])
    }

    /// Text content of this element and all of its descendants, in document order
    var stringValue: String {
        var result = ""
        for piece in content {
            switch piece {
            case .text(let string):
                result += string
            case .element(let element):
                result += element.stringValue
            }
        }
        return result
    }

    // Text and child elements in document order, so mixed content keeps its order
    private enum Content {
        case text(String)
        case element(XMLTreeElement)
    }

    private var content: [Content] = []

    fileprivate func append(child: XMLTreeElement) {
        flushText()
        children.append(child)
        content.append(.element(child))
    }

    fileprivate func append(text string: String) {
        text += string
    }

    fileprivate func flushText() {
        guard !text.isEmpty else { return }
        content.append(.text(text))
        text = ""
    }
}

/// Builds an `XMLTreeElement` tree from XML data
final class XMLTreeBuilder: NSObject, XMLParserDelegate {
    private var root: XMLTreeElement?
    private var stack: [XMLTreeElement] = []

    /// Parses XML data and returns the root element, or nil if the document is empty
    static func parse(_ data: Data) throws -> XMLTreeElement? {
        let builder = XMLTreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw parser.parserError ?? DocumentXMLParserError.invalidXML("Unknown XML error")
        }
        return builder.root
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = XMLTreeElement(name: elementName, attributes: attributeDict)
        if let parent = stack.last {
            parent.append(child: element)
        } else {
            root = element
        }
        stack.append(element)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        stack.popLast()?.flushText()
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.append(text: string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else { return }
        stack.last?.append(text: string)
    }
}
