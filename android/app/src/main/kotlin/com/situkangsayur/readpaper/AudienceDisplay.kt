package com.situkangsayur.readpaper

import android.app.Activity
import android.app.Presentation
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Layar audiens mode presenter di layar eksternal (HDMI, USB-C, cast).
 *
 * Android menampilkan isi lain di layar kedua lewat [Presentation]: jendela
 * milik Activity ini yang tinggal di layar itu. Isinya mesin Flutter kedua
 * yang menjalankan `audienceMain` — layar audiens yang sama dengan jendela
 * audiens di desktop. Pesan presenter diteruskan ke sana apa adanya (JSON),
 * dan tombol clicker yang ditekan saat layar audiens yang fokus dikirim balik.
 */
class AudienceDisplay(private val activity: Activity, private val presenter: MethodChannel) {
    private var engine: FlutterEngine? = null
    private var view: FlutterView? = null
    private var presentation: Presentation? = null
    private var toAudience: MethodChannel? = null
    private var displayId: Int? = null

    /**
     * Pesan yang tiba sebelum layar audiens siap. Mesin kedua butuh sesaat
     * untuk memulai Dart; tanpa antrean, slide pertama — yang dikirim
     * presenter tepat setelah membuka — hilang, dan layar audiens tetap
     * "menunggu presenter" sampai ada yang berubah.
     */
    private val queue = mutableListOf<String>()
    private var ready = false

    private val displays: DisplayManager =
        activity.getSystemService(Activity.DISPLAY_SERVICE) as DisplayManager

    private val listener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(id: Int) {}
        override fun onDisplayChanged(id: Int) {}
        override fun onDisplayRemoved(id: Int) {
            // Kabel dicabut atau cast berhenti.
            if (id == displayId) close(notify = true)
        }
    }

    /** Membuka layar audiens; false bila tidak ada layar eksternal. */
    fun open(): Boolean {
        if (presentation != null) return true
        val display: Display = displays
            .getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
            .firstOrNull() ?: return false

        val loader = FlutterInjector.instance().flutterLoader()
        val flutter = FlutterEngine(activity.applicationContext)
        flutter.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "audienceMain"),
        )
        toAudience = MethodChannel(flutter.dartExecutor.binaryMessenger, AUDIENCE_CHANNEL)
        MethodChannel(flutter.dartExecutor.binaryMessenger, PRESENTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ready" -> flush()
                    "key" -> presenter.invokeMethod("key", call.arguments)
                }
                result.success(null)
            }

        val screen = object : Presentation(activity, display) {
            override fun onCreate(savedInstanceState: Bundle?) {
                super.onCreate(savedInstanceState)
                // Tidak bisa difokus: tombol clicker Bluetooth selalu sampai ke
                // presenter. Tanpa ini layar audiens merebut fokus saat dibuka
                // dan tombol pertama hilang.
                window?.addFlags(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE)
                val flutterView = FlutterView(context)
                flutterView.attachToFlutterEngine(flutter)
                view = flutterView
                setContentView(flutterView)
            }
        }
        screen.setOnDismissListener { close(notify = true) }
        screen.show()
        flutter.lifecycleChannel.appIsResumed()

        engine = flutter
        presentation = screen
        displayId = display.displayId
        ready = false
        queue.clear()
        displays.registerDisplayListener(listener, Handler(Looper.getMainLooper()))
        return true
    }

    fun send(json: String) {
        if (presentation == null) return
        if (!ready) {
            queue.add(json)
            return
        }
        toAudience?.invokeMethod("message", json)
    }

    private fun flush() {
        ready = true
        for (json in queue) toAudience?.invokeMethod("message", json)
        queue.clear()
    }

    /** Menutup layar audiens. [notify]: ditutup dari sisi layar, bukan presenter. */
    fun close(notify: Boolean = false) {
        val screen = presentation ?: return
        presentation = null
        displays.unregisterDisplayListener(listener)
        screen.setOnDismissListener(null)
        if (screen.isShowing) screen.dismiss()
        view?.detachFromFlutterEngine()
        view = null
        engine?.destroy()
        engine = null
        toAudience = null
        displayId = null
        queue.clear()
        if (notify) presenter.invokeMethod("closed", null)
    }

    companion object {
        const val CHANNEL = "readpaper/layar"
        private const val AUDIENCE_CHANNEL = "readpaper/audiens"
        private const val PRESENTER_CHANNEL = "readpaper/presenter"
    }
}
