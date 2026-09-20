package com.example.drink_water

import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI and a tiny sound channel.
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
