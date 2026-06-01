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
    /// Returns `nil` if rendering fails for any reason.
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

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)

        let pageCount = renderer.numberOfPages
        for i in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: pageRect)
        }

        UIGraphicsEndPDFContext()

        return pdfData as Data
    }
}
