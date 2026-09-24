package com.example.drink_water

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale

/**
 * Today's water total on the home screen, with two buttons that log a drink
 * without opening the app.
 *
 * A tap goes to [WidgetActionReceiver], which appends the drink through
 * [WidgetStore], raises the app's pending-refresh flag, and calls back into
 * [refreshAll] so the widget redraws from what it just wrote. The app never has to
 * be running for any of that.
 */
class WaterWidgetProvider : AppWidgetProvider() {

    companion object {
        /**
         * Redraws every placed instance. Called from here after a tap, and from
         * [MainActivity] when the app goes to the background, so the home screen
         * does not keep a figure the app has already moved on from.
         */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, WaterWidgetProvider::class.java)
            )
            for (id in ids) render(context, manager, id)
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_water)

            val total = WidgetStore.totalToday(context)
            val config = WidgetStore.waterConfig(context)
            val small = config.glassMl
            val large = config.bottleMl

            views.setTextViewText(R.id.water_total, format(config, total))
            views.setTextViewText(R.id.water_add_small, "+" + formatShort(config, small))
            views.setTextViewText(R.id.water_add_large, "+" + formatShort(config, large))

            // The goal is always a real number — `WaterSettings` clamps it into
            // 200..20000, and [WidgetStore.waterConfig] applies the same floor —
            // so there is no "no goal yet" state to render.
            //
            // Capped for the bar but not for the label: someone who drank 140% of
            // their goal should see that, while a bar past full would look broken.
            val percent = (total * 100L / config.goalMl).toInt()
            views.setProgressBar(R.id.water_progress, 100, percent.coerceIn(0, 100), false)
            views.setTextViewText(
                R.id.water_percent,
                String.format(Locale.US, "%d%%", percent.coerceAtLeast(0)),
            )
            val remaining = config.goalMl - total
            views.setTextViewText(
                R.id.water_subtitle,
                if (remaining > 0) {
                    context.getString(
                        R.string.widget_water_to_go,
                        format(config, remaining),
                        format(config, config.goalMl),
                    )
                } else {
                    context.getString(
                        R.string.widget_water_reached,
                        format(config, config.goalMl),
                    )
                },
            )

            // Fixed request codes rather than the amounts themselves: a user whose
            // glass and bottle are the same size would otherwise give both buttons
            // one PendingIntent.
            views.setOnClickPendingIntent(R.id.water_add_small, addIntent(context, small, 1))
            views.setOnClickPendingIntent(R.id.water_add_large, addIntent(context, large, 2))
            // Anywhere that is not a button opens the app, which is what people try
            // first on a widget showing a figure they want the detail behind.
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))

            manager.updateAppWidget(id, views)
        }

        private fun addIntent(context: Context, amountMl: Int, slot: Int): PendingIntent {
            // Aimed at the unexported [WidgetActionReceiver] rather than at this
            // provider, which has to be exported for the launcher's sake.
            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_ADD_WATER
                putExtra(WidgetActionReceiver.EXTRA_AMOUNT, amountMl)
            }
            return PendingIntent.getBroadcast(
                context,
                // Distinct per button, so the second cannot reuse the first's
                // extras and log the wrong amount. FLAG_UPDATE_CURRENT then keeps
                // each one's extras fresh when the user resizes their containers.
                slot,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun launchIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * A volume in whatever unit the user picked, mirroring Dart's
         * `formatVolumeCompact`. Following the setting matters: someone who set
         * "glasses" would otherwise read millilitres on the home screen and
         * glasses one tap away, inside the same app.
         *
         * The abbreviated "gl" / "btl" rather than the spelled-out words for the
         * same reason the app uses them in its tight spots — "2.5 glasses to go ·
         * goal 8 glasses" does not fit a three-by-two cell.
         */
        private fun format(config: WidgetStore.WaterConfig, ml: Int): String =
            when (config.unit) {
                WidgetStore.VolumeUnit.ML -> String.format(Locale.US, "%d ml", ml)
                WidgetStore.VolumeUnit.LITER -> {
                    val litres = ml / 1000.0
                    trim(litres, if (litres < 10) 2 else 1) + " L"
                }
                WidgetStore.VolumeUnit.GLASS -> trim(ml / config.glassMl.toDouble(), 1) + " gl"
                WidgetStore.VolumeUnit.BOTTLE -> trim(ml / config.bottleMl.toDouble(), 1) + " btl"
            }

        /**
         * Button labels have far less room, so the unit is dropped — except for
         * litres, where a bare "0.75" beside a "+" would read as an amount in no
         * unit at all.
         */
        private fun formatShort(config: WidgetStore.WaterConfig, ml: Int): String =
            when (config.unit) {
                WidgetStore.VolumeUnit.ML -> ml.toString()
                WidgetStore.VolumeUnit.LITER -> {
                    val litres = ml / 1000.0
                    trim(litres, if (litres < 10) 2 else 1) + "L"
                }
                WidgetStore.VolumeUnit.GLASS -> trim(ml / config.glassMl.toDouble(), 1)
                WidgetStore.VolumeUnit.BOTTLE -> trim(ml / config.bottleMl.toDouble(), 1)
            }

        /** Dart's `_trim`: fixed decimals, then drop any that turned out to be zero. */
        private fun trim(value: Double, decimals: Int): String {
            var text = String.format(Locale.US, "%.${decimals}f", value)
            if (text.contains('.')) {
                text = text.trimEnd('0').trimEnd('.')
            }
            return text
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        // Let the base class handle the system broadcasts (update, delete,
        // options changed) before looking at our own.
        super.onReceive(context, intent)

        when (intent.action) {
            // The total is "today's", so it has to be redrawn when today changes.
            // Cheaper and far kinder to the battery than polling for midnight —
            // though see the manifest on which of these actually still arrive.
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> refreshAll(context)
        }
    }
}
