package com.lampstandhq.introibo.export

import android.content.Context
import android.content.Intent

/**
 * Sharing helpers for HTML export on Android.
 *
 * On Android, true PDF generation from HTML requires an async WebView
 * print pipeline. Instead we share the fully-styled HTML as text —
 * email clients and note apps render it, and the user can open it in
 * any browser and print to PDF from there via the system print dialog.
 *
 * This is the zero-configuration approach: no FileProvider, no manifest
 * changes, no cache-directory management.
 */
object PDFExporter {

    /**
     * Creates a share Intent that sends the raw HTML as text with
     * `text/html` MIME type. Most receiving apps (Gmail, Keep, etc.)
     * will render the HTML correctly.
     *
     * @param html  Complete HTML document string
     * @param title Share chooser title
     * @return A configured ACTION_SEND Intent
     */
    fun shareHTMLIntent(html: String, title: String = "Share Propers"): Intent {
        return Intent(Intent.ACTION_SEND).apply {
            type = "text/html"
            putExtra(Intent.EXTRA_TEXT, html)
            putExtra(Intent.EXTRA_HTML_TEXT, html)
        }
    }
}
