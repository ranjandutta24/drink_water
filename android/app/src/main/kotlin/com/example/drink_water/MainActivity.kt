package com.example.drink_water

import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI, a tiny sound channel, and the home screen widget refresh.
 *
 * There is deliberately no widget method channel — see [refreshWidgets].
 *
 * The one short effect this app plays (a swallow, when water is logged) is not
 * worth an audio package: SoundPool decodes it once when the engine is
 * configured and replays it with no per-call setup, which is exactly its
 * purpose. Loading is asynchronous, so the very first tap of a cold start may
 * find it unready and stay silent rather than stalling the UI. Using the
 * media stream rather than the notification stream is deliberate — this is a
 * direct response to a tap, so it should follow media volume and stay silent
 * when the user has turned that down.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "drink_water/sound"
    }

    private var soundPool: SoundPool? = null

    /** Non-zero once the asset has finished loading; SoundPool ids start at 1. */
    private var swallowId = 0

    /** Set by the load listener — playing before this is a silent no-op. */
    private var swallowReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureSoundPool()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playSwallow" -> {
                    playSwallow()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

    }

    /**
     * Redraws both widgets from whatever is on disk now.
     *
     * Driven from [onPause] rather than from Dart over a method channel. The home
     * screen only becomes visible once the app is on its way out, so a single hook
     * there covers every write path there is; a channel would be a second
     * mechanism for the same job, and one the save paths could forget to call.
     */
    private fun refreshWidgets() {
        // Off the main thread: rendering reads SharedPreferences and parses the
        // whole water log, and doing that inside onPause would put a disk read and
        // a JSON parse on the critical path of the closing animation (and trip
        // StrictMode). The application context, not the activity, because this
        // outlives the activity it was started from.
        val context = applicationContext
        Thread {
            try {
                WaterWidgetProvider.refreshAll(context)
                MedicineWidgetProvider.refreshAll(context)
            } catch (error: Exception) {
                // A launcher with no instances placed, or an unusual widget host,
                // must not be able to take the app down over a cosmetic refresh.
                Log.w("MainActivity", "Widget refresh failed", error)
            }
        }.start()
    }

    override fun onPause() {
        // The most likely moment for the home screen to become visible is the app
        // going away, so this is the cheapest place to guarantee the widget is
        // current — it covers any write path that forgot to ask.
        refreshWidgets()
        super.onPause()
    }

    override fun onDestroy() {
        // Held for the whole activity rather than released in onStop. The decoded
        // buffer is well under a hundred kilobytes, and tearing it down on every
        // background trip would both truncate a sound still playing and leave the
        // first tap after each resume silent while the asset reloaded.
        releaseSoundPool()
        super.onDestroy()
    }

    private fun ensureSoundPool() {
        if (soundPool != null) return

        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val pool = SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(attributes)
            .build()

        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (sampleId == swallowId && status == 0) swallowReady = true
        }

        soundPool = pool
        swallowReady = false
        swallowId = pool.load(this, R.raw.water_swallow, 1)
    }

    private fun releaseSoundPool() {
        soundPool?.release()
        soundPool = null
        swallowId = 0
        swallowReady = false
    }

    private fun playSwallow() {
        val pool = soundPool ?: return
        if (!swallowReady || swallowId == 0) return
        pool.play(swallowId, 1f, 1f, 1, 0, 1f)
    }
}
