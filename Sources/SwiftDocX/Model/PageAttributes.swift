import Foundation


/// Represents attributes of a page, including paper size and margins.
public struct PageAttributes: Equatable, Sendable {
    /// The page width, in points. (72 pts per inch). Defaults to 8.5" (612 pts).
    public var width: Double = 612.0

    /// The page height, in points (72 pts per inch). Defaults to 11" (792 pts).
    public var height: Double = 792.0

    /// The margins of the page, including margins for the page header/footer.
    public var margins: PageMargins

    /// Initializes a `PageAttributes` with the default 8.5 x 11" page size, 1" margins, and 0.5" margins for the header/footer.
    public init(width: Double = 612.0, height: Double = 792.0, margins: PageMargins = .init()) {
        self.width = width
        self.height = height
        self.margins = margins
    }
}


/// Represents the margins of a page.
public struct PageMargins: Equatable, Sendable {
    /// The page's top margin, in points (1 inch = 72 points). Defaults to 72.
    public var top: Double = 72.0

    /// The page's bottom margin, in points (1 inch = 72 points). Defaults to 72.
    public var bottom: Double = 72.0

    /// The page's left margin, in points (1 inch = 72 points). Defaults to 72.
    public var left: Double = 72.0

    /// The page's right margin, in points (1 inch = 72 points). Defaults to 72.
    public var right: Double = 72.0

    /// The margin for the page header, in points (1 inch = 72 points). Defaults to 36.
    public var header: Double = 36.0

    /// The margin for the page footer, in points (1 inch = 72 points). Defaults to 36.
    public var footer: Double = 36.0

    /// Initializes a `PageMargins`. By default, all edges are 1" margins (72 points) and the page header and footer have 0.5" margins (36 points).
    public init(top: Double = 72.0, bottom: Double = 72.0, left: Double = 72.0, right: Double = 72.0, header: Double = 36.0, footer: Double = 36.0)
    {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.header = header
        self.footer = footer
    }
}


