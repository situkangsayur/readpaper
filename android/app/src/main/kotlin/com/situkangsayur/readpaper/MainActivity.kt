package com.situkangsayur.readpaper

import android.app.Activity
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
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
    private var audience: AudienceDisplay? = null
    private var folderResult: MethodChannel.Result? = null

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
                    // Gambar di papan klip ("Salin gambar" di peramban), untuk
                    // ditempel di halaman. Dibaca di utas lain: isinya bisa
                    // beberapa megabita dari penyedia konten aplikasi lain.
                    "clipboardImage" -> Thread {
                        val bytes = readClipboardImage()
                        runOnUiThread { result.success(bytes) }
                    }.start()
                    // "Tambahkan folder…": pemilih folder sistem, lalu isinya
                    // disalin ke cache. Jalur dari getDirectoryPath tidak bisa
                    // dibaca dart:io di Android 11+ tanpa izin semua berkas.
                    "pickFolderCopy" -> pickFolderCopy(result)
                    else -> result.notImplemented()
                }
            }
        }
        // Layar audiens mode presenter di layar eksternal.
        val display = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AudienceDisplay.CHANNEL)
        val screen = AudienceDisplay(this, display)
        audience = screen
        display.setMethodCallHandler { call, result ->
            when (call.method) {
                "open" -> result.success(screen.open())
                "send" -> {
                    screen.send(call.arguments as String)
                    result.success(null)
                }
                "close" -> {
                    screen.close()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        audience?.close()
        super.onDestroy()
    }

    private fun pickFolderCopy(result: MethodChannel.Result) {
        // Pemilih yang tertinggal dijawab batal dulu, supaya Dart tidak
        // menunggu selamanya.
        folderResult?.success(null)
        folderResult = result
        try {
            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), PICK_FOLDER)
        } catch (e: Exception) {
            folderResult = null
            result.error("tanpa-pemilih", e.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_FOLDER) return
        val result = folderResult ?: return
        folderResult = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return
        }
        // Folder berisi ratusan PDF bisa butuh waktu; jangan di utas UI.
        Thread {
            try {
                val root = DocumentsContract.getTreeDocumentId(tree)
                val name = treeName(tree, root)
                val base = File(cacheDir, "folder-masuk").apply {
                    deleteRecursively()
                    mkdirs()
                }
                val target = File(base, safeName(name)).apply { mkdirs() }
                copyTree(tree, root, target)
                runOnUiThread { result.success(target.absolutePath) }
            } catch (e: Exception) {
                runOnUiThread { result.error("gagal-salin", e.message, null) }
            }
        }.start()
    }

    private fun treeName(tree: Uri, documentId: String): String {
        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, documentId)
        contentResolver.query(
            uri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0)?.let { if (it.isNotBlank()) return it }
        }
        return documentId.substringAfterLast(':').substringAfterLast('/').ifBlank { "Folder" }
    }

    /** Menyalin isi folder [documentId] ke [target], berikut subfoldernya. */
    private fun copyTree(tree: Uri, documentId: String, target: File) {
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, documentId)
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(children, columns, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0) ?: continue
                val name = cursor.getString(1) ?: continue
                // Sama dengan FolderScan.skipped di sisi Dart: .git dan
                // sejenisnya tidak perlu disalin sama sekali.
                if (name.startsWith(".")) continue
                val file = File(target, safeName(name))
                if (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                    file.mkdirs()
                    copyTree(tree, id, file)
                } else {
                    val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                    contentResolver.openInputStream(uri)?.use { input ->
                        file.outputStream().use { output -> input.copyTo(output) }
                    }
                }
            }
        }
    }

    private fun safeName(name: String): String = name.replace('/', '_').ifBlank { "_" }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Aplikasi sudah berjalan dan sebuah berkas dibuka dari tempat lain:
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
                    val known = KNOWN_EXTENSIONS.any { value.endsWith(it, ignoreCase = true) }
                    return if (known) value else "$value${extensionFor(uri)}"
                }
            }
        }
        return uri.lastPathSegment
    }

    private fun readClipboardImage(): ByteArray? {
        val manager = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        val clip = manager.primaryClip ?: return null
        for (i in 0 until clip.itemCount) {
            val uri = clip.getItemAt(i).uri ?: continue
            val type = contentResolver.getType(uri) ?: continue
            if (!type.startsWith("image/")) continue
            return try {
                contentResolver.openInputStream(uri)?.use { it.readBytes() }
            } catch (e: Exception) {
                null
            }
        }
        return null
    }

    private fun extensionFor(uri: Uri): String =
        MIME_EXTENSIONS[contentResolver.getType(uri)] ?: ".pdf"

    private companion object {
        const val CHANNEL = "readpaper/berkas-masuk"
        const val PICK_FOLDER = 4117

        /** Tipe yang didaftarkan di manifest → akhiran yang dikenali sisi Dart. */
        val MIME_EXTENSIONS = mapOf(
            "application/pdf" to ".pdf",
            "application/epub+zip" to ".epub",
            "application/msword" to ".doc",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document" to ".docx",
            "application/rtf" to ".rtf",
            "text/rtf" to ".rtf",
            "application/vnd.ms-powerpoint" to ".ppt",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation" to ".pptx",
            "application/vnd.openxmlformats-officedocument.presentationml.slideshow" to ".ppsx",
            "application/vnd.ms-excel" to ".xls",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" to ".xlsx",
            "text/csv" to ".csv",
        )

        val KNOWN_EXTENSIONS = MIME_EXTENSIONS.values.toSet() +
            setOf(".pps", ".dot", ".dotx", ".docm", ".pptm", ".potx", ".pot", ".xlsm", ".tsv")
    }
}
