package com.urbiztondo.smartflow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.content.Context
import android.print.PrintAttributes
import android.print.PrintManager
import android.print.PrintDocumentAdapter
import android.print.PageRange
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.webkit.WebView
import android.webkit.WebViewClient

class MainActivity : FlutterActivity() {
    private var exportResult: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private val exportRequest = 9876

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smartflow/qr_export")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePng") { result.notImplemented(); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename") ?: "SmartFlow-QR.png"
                if (bytes == null || bytes.size > 4 * 1024 * 1024 || !Regex("DOC-[0-9]{4}-[0-9]{6}-QR\\.png").matches(filename)) {
                    result.error("invalid_export", "Invalid QR image", null)
                    return@setMethodCallHandler
                }
                if (exportResult != null) { result.error("busy", "An export is already open", null); return@setMethodCallHandler }
                exportResult = result
                exportBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "image/png"
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }
                    startActivityForResult(intent, exportRequest)
                } catch (e: Exception) {
                    exportResult = null; exportBytes = null
                    result.error("export_failed", "Could not open file picker", null)
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smartflow/report_export")
            .setMethodCallHandler { call, result ->
                if (call.method == "printReport") {
                    val html = call.argument<String>("html")
                    if (html == null || html.length > 4 * 1024 * 1024 || !html.startsWith("<!doctype html>")) {
                        result.error("invalid_export", "Invalid report", null); return@setMethodCallHandler
                    }
                    try {
                        val webView = WebView(this)
                        webView.settings.javaScriptEnabled = false
                        webView.settings.blockNetworkLoads = true
                        webView.webViewClient = object : WebViewClient() {
                            private var opened = false
                            override fun onPageFinished(view: WebView, url: String?) {
                                if (opened) return
                                opened = true
                                try {
                                    val manager = getSystemService(Context.PRINT_SERVICE) as PrintManager
                                    val delegate = view.createPrintDocumentAdapter("SmartFlow custody summary")
                                    val adapter = object : PrintDocumentAdapter() {
                                        override fun onStart() { delegate.onStart() }
                                        override fun onLayout(oldAttributes: PrintAttributes?, newAttributes: PrintAttributes?, signal: CancellationSignal?, callback: LayoutResultCallback?, extras: Bundle?) { delegate.onLayout(oldAttributes, newAttributes, signal, callback, extras) }
                                        override fun onWrite(pages: Array<out PageRange>?, destination: ParcelFileDescriptor?, signal: CancellationSignal?, callback: WriteResultCallback?) { delegate.onWrite(pages, destination, signal, callback) }
                                        override fun onFinish() { delegate.onFinish(); view.destroy() }
                                    }
                                    manager.print("SmartFlow custody summary", adapter, PrintAttributes.Builder().setMediaSize(PrintAttributes.MediaSize.ISO_A4).build())
                                    result.success(true)
                                } catch (e: Exception) { view.destroy(); result.error("print_failed", "Could not open print preview", null) }
                            }
                        }
                        webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
                    } catch (e: Exception) { result.error("print_failed", "Could not open print preview", null) }
                    return@setMethodCallHandler
                }
                if (call.method != "saveCsv") { result.notImplemented(); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("bytes")
                val filename = call.argument<String>("filename") ?: ""
                val validFilename = Regex("SmartFlow-custody-(month|quarter|year)-[0-9]{4}-[0-9]{2}-[0-9]{2}\\.csv").matches(filename) || Regex("SmartFlow-scan-audit-[0-9]{8}-[0-9]{6}\\.csv").matches(filename)
                if (bytes == null || bytes.size > 4 * 1024 * 1024 || !validFilename) {
                    result.error("invalid_export", "Invalid report file", null); return@setMethodCallHandler
                }
                if (exportResult != null) { result.error("busy", "An export is already open", null); return@setMethodCallHandler }
                exportResult = result; exportBytes = bytes
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/csv"
                        putExtra(Intent.EXTRA_TITLE, filename)
                    }
                    startActivityForResult(intent, exportRequest)
                } catch (e: Exception) {
                    exportResult = null; exportBytes = null
                    result.error("export_failed", "Could not open file picker", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest) return
        val result = exportResult ?: return
        val bytes = exportBytes
        exportResult = null; exportBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) { result.success(false); return }
        try {
            val stream = contentResolver.openOutputStream(data.data!!) ?: throw IllegalStateException("No output stream")
            stream.use { it.write(bytes ?: throw IllegalStateException("No image")) }
            result.success(true)
        } catch (e: Exception) { result.error("export_failed", "Could not save file", null) }
    }
}
