package com.situkangsayur.readpaper

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Menerima PDF yang dibuka dari aplikasi lain.
 *
 * Android menyerahkan berkasnya sebagai `content://` URI yang hanya boleh
 * dibaca selama Activity ini hidup, jadi isinya disalin ke cache lebih dulu.
 * Sisi Dart hanya menerima sebuah jalur berkas biasa — sama seperti berkas
 * yang dipilih sendiri lewat pemilih berkas.
 */
class MainActivity : FlutterActivity() {
    private var pending: String? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    // Dipanggil sekali saat aplikasi siap: berkas yang membuka
                    // aplikasi ini, kalau ada.
                    "takeInitialPdf" -> {
                        val path = pending ?: copyIncoming(intent)
                        pending = null
                        result.success(path)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Aplikasi sudah berjalan dan sebuah PDF dibuka dari tempat lain:
        // jalurnya dikirim langsung, tidak menunggu ditanya.
        val path = copyIncoming(intent) ?: return
        val sink = channel
        if (sink != null) sink.invokeMethod("openPdf", path) else pending = path
    }

    /** Menyalin isi URI masuk ke cache, mengembalikan jalurnya. */
    private fun copyIncoming(intent: Intent?): String? {
        val uri: Uri = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        } ?: return null

        return try {
            val name = displayName(uri) ?: "dokumen${extensionFor(uri)}"
            val dir = File(cacheDir, "masuk").apply { mkdirs() }
            val target = File(dir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            target.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val column = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (column >= 0 && cursor.moveToFirst()) {
                val value = cursor.getString(column)
                if (!value.isNullOrBlank()) {
                    // Akhirannya yang menentukan pembaca mana yang membuka
                    // berkasnya di sisi Dart, jadi nama tanpa akhiran diberi
                    // akhiran dari tipenya — bukan selalu ".pdf".
                    val known = value.endsWith(".pdf", ignoreCase = true) ||
                        value.endsWith(".epub", ignoreCase = true)
                    return if (known) value else "$value${extensionFor(uri)}"
                }
            }
        }
        return uri.lastPathSegment
    }

    private fun extensionFor(uri: Uri): String =
        if (contentResolver.getType(uri) == "application/epub+zip") ".epub" else ".pdf"

    private companion object {
        const val CHANNEL = "readpaper/berkas-masuk"
    }
}
