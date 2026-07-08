package com.lampstandhq.introibo.export

import android.content.Context
import android.content.Intent
import android.graphics.pdf.PdfDocument
import android.util.Log
import android.view.View
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

/**
 * Real PDF export from the styled HTML documents (MassHTMLExporter).
 *
 * Renders the HTML in an offscreen WebView, then draws it page by page into
 * an android.graphics.pdf.PdfDocument — US Letter (612x792pt) with 36pt
 * margins, the same page geometry as the iOS PDFExporter.
 *
 * Two Android gotchas handled here:
 *  * WebView.enableSlowWholeDocumentDraw() must be called before ANY WebView
 *    is created, or offscreen draw() only produces the visible tile (blank
 *    or truncated pages).
 *  * The WebView lays text out in density-scaled pixels while PDF canvases
 *    are in points — we render at pixel scale and shrink by 1/density.
 *
 * Falls back to sharing the HTML as text if PDF generation fails.
 */
object PDFExporter {

    private const val PAGE_W = 612          // US Letter, PostScript points
    private const val PAGE_H = 792
    private const val MARGIN = 36           // 0.5in — matches iOS
    private const val CONTENT_W = PAGE_W - 2 * MARGIN
    private const val CONTENT_H = PAGE_H - 2 * MARGIN

    /**
     * Renders [html] to a PDF and opens the system share sheet.
     * Must be called from the main thread (WebView requirement).
     */
    fun sharePDF(context: Context, html: String, fileName: String, title: String = "Share") {
        WebView.enableSlowWholeDocumentDraw()

        val density = context.resources.displayMetrics.density
        val contentWpx = (CONTENT_W * density).toInt()
        val contentHpx = (CONTENT_H * density).toInt()

        val webView = WebView(context)
        webView.settings.javaScriptEnabled = false
        // Give the view its real width BEFORE loading so the page lays out
        // once, at the printable width.
        webView.layout(0, 0, contentWpx, contentHpx)
        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String?) {
                // Let the engine finish async layout before drawing.
                view.postDelayed({
                    try {
                        writePdf(context, view, density, contentWpx, contentHpx, fileName, title)
                    } catch (t: Throwable) {
                        Log.e("PDFExporter", "PDF generation failed", t)
                        fallbackToHTML(context, html, title)
                    }
                }, 250)
            }
        }
        webView.loadDataWithBaseURL(null, html, "text/html", "utf-8", null)
    }

    private fun writePdf(
        context: Context,
        webView: WebView,
        density: Float,
        contentWpx: Int,
        contentHpx: Int,
        fileName: String,
        title: String,
    ) {
        webView.measure(
            View.MeasureSpec.makeMeasureSpec(contentWpx, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
        )
        webView.layout(0, 0, contentWpx, webView.measuredHeight)
        val totalHpx = maxOf(
            webView.measuredHeight,
            (webView.contentHeight * density).toInt(),
            1,
        )

        val doc = PdfDocument()
        var pageIndex = 0
        while (pageIndex * contentHpx < totalHpx) {
            val page = doc.startPage(
                PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, pageIndex + 1).create()
            )
            with(page.canvas) {
                translate(MARGIN.toFloat(), MARGIN.toFloat())
                clipRect(0, 0, CONTENT_W, CONTENT_H)
                // Points -> WebView pixels, then slide up to this page's slice.
                scale(1f / density, 1f / density)
                translate(0f, -(pageIndex * contentHpx).toFloat())
                webView.draw(this)
            }
            doc.finishPage(page)
            pageIndex++
        }

        val exportDir = File(context.cacheDir, "exports").apply { mkdirs() }
        val safeName = fileName.replace(Regex("[^\\p{L}\\p{N} .,-]"), "").ifBlank { "Introibo" }
        val outFile = File(exportDir, "$safeName.pdf")
        FileOutputStream(outFile).use { doc.writeTo(it) }
        doc.close()

        shareFile(context, outFile, title)
    }

    private fun shareFile(context: Context, file: File, title: String) {
        val uri = FileProvider.getUriForFile(
            context, "${context.packageName}.fileprovider", file,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            this.type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, title))
    }

    private fun fallbackToHTML(context: Context, html: String, title: String) {
        context.startActivity(Intent.createChooser(shareHTMLIntent(html, title), title))
    }

    /** Legacy fallback: shares the raw HTML as text (`text/html`). */
    fun shareHTMLIntent(html: String, title: String = "Share Propers"): Intent {
        return Intent(Intent.ACTION_SEND).apply {
            this.type = "text/html"
            putExtra(Intent.EXTRA_TEXT, html)
            putExtra(Intent.EXTRA_HTML_TEXT, html)
        }
    }
}
