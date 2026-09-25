package com.example.drink_water

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles the taps on the widget buttons: logging a drink, marking a dose taken.
 *
 * Why this is not simply folded into the two providers, which already receive
 * broadcasts: an `AppWidgetProvider` has to be exported, because the launcher and
 * the system send it APPWIDGET_UPDATE from outside this app. Exported means any
 * installed app can send it anything, and a provider that also handled
 * WIDGET_ADD_WATER would let a third party write into the user's health log. This
 * receiver is not exported, so only a PendingIntent this app created can reach it.
 *
 * Both handlers write through [WidgetStore], which raises the app's
 * pending-refresh flag, and then redraw both widgets — the water total and the
 * dose count are shown on one widget each, but a medicine reminder often comes
 * with a glass of water, so refreshing the pair costs one extra read and avoids a
 * stale figure sitting next to a fresh one.
 */
class WidgetActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ADD_WATER = "com.example.drink_water.WIDGET_ADD_WATER"
        const val ACTION_DOSE_TAKEN = "com.example.drink_water.WIDGET_DOSE_TAKEN"
        const val EXTRA_AMOUNT = "amountMl"
        const val EXTRA_MEDICINE_ID = "medicineId"

        /**
         * Minute of day of the dose being answered. A dose has to say which slot
         * it settles, or a medicine due several times a day cannot tell its own
         * doses apart. -1 means none was known.
         */
        const val EXTRA_SLOT_MINUTE = "slotMinute"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_ADD_WATER -> {
                val amount = intent.getIntExtra(EXTRA_AMOUNT, 0)
                if (amount > 0) WidgetStore.addWater(context, amount)
            }
            ACTION_DOSE_TAKEN -> {
                val id = intent.getStringExtra(EXTRA_MEDICINE_ID)
                val slot = intent.getIntExtra(EXTRA_SLOT_MINUTE, -1)
                if (!id.isNullOrEmpty()) WidgetStore.recordTaken(context, id, slot)
            }
            // Anything else is not ours; nothing to do, and nothing to redraw.
            else -> return
        }

        // Synchronous on purpose. A receiver is allowed roughly ten seconds and
        // can be torn down the moment onReceive returns, so handing this to a
        // thread would race the process going away — and WidgetStore has already
        // done the only slow part, the commit(), by this point.
        WaterWidgetProvider.refreshAll(context)
        MedicineWidgetProvider.refreshAll(context)
    }
}
