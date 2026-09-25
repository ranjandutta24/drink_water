package com.example.drink_water

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

/**
 * The next medicine dose due today, with a button to mark it taken.
 *
 * Shows one dose rather than a list: a RemoteViews list needs a
 * RemoteViewsService and an adapter, and on a widget this size it would mean
 * scrolling to reach the thing you came for. The count in the corner is what
 * carries the rest of the day.
 */
class MedicineWidgetProvider : AppWidgetProvider() {

    companion object {
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MedicineWidgetProvider::class.java)
            )
            for (id in ids) render(context, manager, id)
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_medicine)

            val doses = WidgetStore.dosesToday(context)
            val next = WidgetStore.nextDose(doses)
            val takenCount = doses.count { it.taken }

            views.setTextViewText(
                R.id.medicine_count,
                if (doses.isEmpty()) "" else "$takenCount/${doses.size}",
            )

            if (next == null) {
                // Two different kinds of "nothing to show", and they deserve
                // different words: a finished day is an achievement, an empty
                // medicine list is a prompt to go and set one up.
                val done = doses.isNotEmpty()
                views.setTextViewText(
                    R.id.medicine_name,
                    context.getString(
                        if (done) R.string.widget_medicine_none
                        else R.string.widget_medicine_empty
                    ),
                )
                views.setTextViewText(
                    R.id.medicine_time,
                    context.getString(
                        if (done) R.string.widget_medicine_none_detail
                        else R.string.widget_medicine_empty_detail
                    ),
                )
                views.setViewVisibility(R.id.medicine_taken, View.GONE)
            } else {
                views.setTextViewText(R.id.medicine_name, next.name)
                views.setTextViewText(R.id.medicine_time, describe(context, next))

                // Always offered, however far off the dose is. The intake records
                // the slot it answers, so the tap settles this dose whatever the
                // clock says. It used to be hidden outside a three-hour window,
                // because back then logging stamped only the moment of the tap and
                // a dose five hours away could not be reached — that limitation is
                // gone, and hiding the button was only ever a way of admitting it.
                views.setViewVisibility(R.id.medicine_taken, View.VISIBLE)
                views.setOnClickPendingIntent(
                    R.id.medicine_taken,
                    takenIntent(context, next.medicineId, next.minuteOfDay),
                )
            }

            views.setOnClickPendingIntent(R.id.medicine_root, launchIntent(context))
            manager.updateAppWidget(id, views)
        }

        /**
         * The dose's time plus how it stands against now, because the time alone
         * does not say whether this is the thing you are late for.
         */
        /** Minutes from now until the dose; negative once it is overdue. */
        private fun minutesUntil(dose: WidgetStore.Dose): Int {
            val now = Calendar.getInstance()
            val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            return dose.minuteOfDay - nowMinutes
        }

        private fun describe(context: Context, dose: WidgetStore.Dose): String {
            val clock = formatTime(context, dose.hour, dose.minute)
            val delta = minutesUntil(dose)

            return when {
                delta > 90 -> clock
                delta > 0 -> context.getString(
                    R.string.widget_medicine_at_in,
                    clock,
                    describeGap(context, delta),
                )
                delta == 0 -> context.getString(R.string.widget_medicine_at_now, clock)
                else -> context.getString(
                    R.string.widget_medicine_at_overdue,
                    clock,
                    describeGap(context, -delta),
                )
            }
        }

        private fun describeGap(context: Context, minutes: Int): String = when {
            minutes < 60 -> context.getString(R.string.widget_gap_minutes, minutes)
            minutes % 60 == 0 -> context.getString(R.string.widget_gap_hours, minutes / 60)
            else -> context.getString(
                R.string.widget_gap_hours_minutes,
                minutes / 60,
                minutes % 60,
            )
        }

        /**
         * Follows the device's 12/24-hour setting rather than the app's own
         * `use24hClock` preference. The widget sits among the launcher's clock and
         * other widgets, so matching the system there looks less out of place than
         * matching the app would.
         *
         * The platform formatter rather than a hand-built string: it already knows
         * this locale's separator and its own words for am/pm, which a literal
         * "am"/"pm" in Kotlin would override with English on every device.
         */
        private fun formatTime(context: Context, hour: Int, minute: Int): String {
            val at = Calendar.getInstance()
            at.set(Calendar.HOUR_OF_DAY, hour)
            at.set(Calendar.MINUTE, minute)
            at.set(Calendar.SECOND, 0)
            return DateFormat.getTimeFormat(context).format(at.time)
        }

        private fun takenIntent(
            context: Context,
            medicineId: String,
            slotMinute: Int,
        ): PendingIntent {
            // Aimed at the unexported [WidgetActionReceiver], so another app cannot
            // write a dose into the log by forging this broadcast.
            val intent = Intent(context, WidgetActionReceiver::class.java).apply {
                action = WidgetActionReceiver.ACTION_DOSE_TAKEN
                putExtra(WidgetActionReceiver.EXTRA_MEDICINE_ID, medicineId)
                putExtra(WidgetActionReceiver.EXTRA_SLOT_MINUTE, slotMinute)
            }
            return PendingIntent.getBroadcast(
                context,
                // Keyed on the medicine so a rebuilt intent for a different
                // medicine cannot reuse the previous one's extras.
                medicineId.hashCode(),
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
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            // Today's plan changes with the date, so the widget has to follow it.
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> refreshAll(context)
        }
    }
}
