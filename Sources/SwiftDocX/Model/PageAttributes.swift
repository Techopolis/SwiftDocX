import Foundation


/// Represents attributes of a page, including paper size and margins.
public struct PageAttributes: Equatable, Sendable {
    /// The page width, in points. (72 pts per inch). Defaults to 8.5" (612 pts).
    public var width: Double = 612.0

    /// The page height, in points (72 pts per inch). Defaults to 11" (792 pts).
    public var height: Double = 792.0

    /// The margins of the page (top, bottom, left, right).
    public var margins: Margins

    /// The margin for the page header, in points (1 inch = 72 points). Defaults to 36.
    public var headerMargin: Double = 36.0

    /// The margin for the page footer, in points (1 inch = 72 points). Defaults to 36.
    public var footerMargin: Double = 36.0

    /// Initializes a `PageAttributes` with the default 8.5 x 11" page size, 1" margins, and 0.5" margins for the header/footer.
    public init(width: Double = 612.0, height: Double = 792.0, margins: Margins = .init(top: 72.0, bottom: 72.0, left: 72.0, right: 72.0), headerMargin: Double = 36.0, footerMargin: Double = 36.0) {
        self.width = width
        self.height = height
        self.margins = margins
        self.headerMargin = headerMargin
        self.footerMargin = footerMargin
    }
}


/// Represents the margins of an element such as a page or table cell.
public struct Margins: Equatable, Sendable {
    /// The element's top margin, in points (1 inch = 72 points). Defaults to 0.
    public var top: Double

    /// The element's bottom margin, in points (1 inch = 72 points). Defaults to 0.
    public var bottom: Double

    /// The element's left margin, in points (1 inch = 72 points). Defaults to 0.
    public var left: Double

    /// The element's right margin, in points (1 inch = 72 points). Defaults to 0.
    public var right: Double

    /// Initializes a `Margins`. By default, all edges are set to 0 points.
    public init(top: Double = 0, bottom: Double = 0, left: Double = 0, right: Double = 0)
    {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
}


