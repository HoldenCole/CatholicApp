import UIKit

/// Renders an HTML string into PDF data using UIKit's print infrastructure.
/// The resulting `Data` can be written to a file and shared via
/// `UIActivityViewController`.
enum PDFExporter {

    /// US Letter page size in points (612 × 792).
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 36

    /// Generates PDF data from a complete HTML document string.
    /// Returns `nil` if rendering fails for any reason — including the
    /// zero-page case, which previously produced a structurally invalid
    /// PDF that receiving apps could not identify or open.
    static func generatePDF(from html: String) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let printableRect = pageRect.insetBy(dx: margin, dy: margin)

        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        formatter.perPageContentInsets = UIEdgeInsets(
            top: margin, left: margin, bottom: margin, right: margin
        )

        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pageCount = renderer.numberOfPages
        guard pageCount > 0 else { return nil }

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return pdfRenderer.pdfData { ctx in
            for i in 0..<pageCount {
                ctx.beginPage()
                renderer.drawPage(at: i, in: pageRect)
            }
        }
    }

    /// Renders `html` to a PDF file in the temp directory, named after
    /// `title` (sanitized, .pdf extension) so Messages/Files/Mail identify
    /// it as a real document. Returns nil if rendering or writing fails —
    /// callers should fall back to their text share rather than presenting
    /// a broken file.
    static func writePDF(from html: String, title: String) -> URL? {
        guard let data = generatePDF(from: html) else { return nil }
        var safe = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if safe.isEmpty { safe = "Introibo" }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safe).pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
