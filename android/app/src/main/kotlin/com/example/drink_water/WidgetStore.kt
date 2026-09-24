package com.example.drink_water

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Reads and writes the same on-device data the Flutter app uses.
 *
 * The home screen widgets have to render, and log, while the app process is not
 * running at all — there is no Flutter engine to ask — so they talk to
 * SharedPreferences directly. Two details make that work:
 *
 *  - The `shared_preferences` plugin namespaces every key it writes with a
 *    `flutter.` prefix inside the `FlutterSharedPreferences` file. Reading
 *    `water_log_v1` without that prefix silently returns null, which would look
 *    exactly like "no data yet" rather than like a bug.
 *  - The values are the very JSON the Dart models emit, so this file has to stay
 *    in step with `WaterEntry.toJson` and `MedicineIntake.toJson`. Anything it
 *    writes is parsed back by `tryFromJson`, which skips entries it cannot read
 *    instead of throwing — so a mistake here loses a drink rather than
 *    corrupting the log.
 *
 * Parsing is deliberately tolerant in the same way the Dart side is: a corrupt
 * payload yields an empty list and a widget that reads zero, never a crash in a
 * broadcast receiver.
 */
internal object WidgetStore {

    private const val PREFS = "FlutterSharedPreferences"
    private const val PREFIX = "flutter."

    private const val KEY_WATER_LOG = PREFIX + "water_log_v1"
    private const val KEY_WATER_SETTINGS = PREFIX + "water_settings_v1"
    private const val KEY_MEDICINES = PREFIX + "medicines_v1"
    private const val KEY_MEDICINE_LOG = PREFIX + "medicine_log_v1"

    /**
     * Mirrors `kPendingRefreshKey` in notification_service.dart. The app checks
     * this on resume and reloads from disk, which is what stops the running UI
     * from later saving its own stale in-memory log over a widget's write.
     */
    private const val KEY_PENDING_REFRESH = PREFIX + "pending_refresh_v1"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // --- Water ---------------------------------------------------------------

    /** Millilitres logged today, by the same local-time day key Dart uses. */
    fun totalToday(context: Context): Int {
        val today = dayKey(Calendar.getInstance())
        var total = 0
        val log = readArray(prefs(context).getString(KEY_WATER_LOG, null))
        for (i in 0 until log.length()) {
            val entry = log.optJSONObject(i) ?: continue
            val stamp = entry.optString("timestamp")
            if (dayKeyOfIso(stamp) != today) continue
            val amount = entry.optInt("amountMl", 0)
            if (amount > 0) total += amount
        }
        return total
    }

    /**
     * How the user wants volumes written. Mirrors Dart's `VolumeUnit`.
     *
     * Not named `Unit`, tempting as that is: nested in this object it would shadow
     * Kotlin's own `Unit` type for every member here.
     */
    enum class VolumeUnit { ML, LITER, GLASS, BOTTLE }

    /**
     * The parts of the water settings the widget needs, read in one pass.
     *
     * Every range here is the range `WaterSettings.fromJson` clamps to. They have
     * to agree: a tighter bound in Kotlin would make the widget's button log a
     * different amount than the same container logs inside the app.
     */
    data class WaterConfig(
        val goalMl: Int,
        val glassMl: Int,
        val bottleMl: Int,
        val unit: VolumeUnit,
    )

    fun waterConfig(context: Context): WaterConfig {
        val settings = readObject(prefs(context).getString(KEY_WATER_SETTINGS, null))
        return WaterConfig(
            goalMl = settings.optInt("dailyGoalMl", 2000).coerceIn(200, 20000),
            glassMl = settings.optInt("glassSizeMl", 250).coerceIn(10, 5000),
            bottleMl = settings.optInt("bottleSizeMl", 750).coerceIn(10, 10000),
            // Dart writes the enum's `name`, and `VolumeUnit.fromName` falls back
            // to millilitres for anything it does not recognise.
            unit = when (settings.optString("displayUnit")) {
                "liter" -> VolumeUnit.LITER
                "glass" -> VolumeUnit.GLASS
                "bottle" -> VolumeUnit.BOTTLE
                else -> VolumeUnit.ML
            },
        )
    }

    /**
     * Appends a drink and flags the app to reload.
     *
     * Newest-first to match how the app keeps the list, and `commit` rather than
     * `apply` because a broadcast receiver can be torn down the moment
     * [android.appwidget.AppWidgetProvider.onReceive] returns — an async write is
     * not guaranteed to have reached disk by then.
     */
    fun addWater(context: Context, amountMl: Int): Boolean {
        if (amountMl <= 0) return false
        val store = prefs(context)
        val log = readArray(store.getString(KEY_WATER_LOG, null))

        val entry = JSONObject()
            .put("id", "w" + System.currentTimeMillis() * 1000)
            .put("timestamp", isoLocal(Calendar.getInstance()))
            .put("amountMl", amountMl)
            // Not `fromNotification`: this came from the home screen, and the day
            // view labels notification drinks differently.
            .put("fromNotification", false)

        val merged = JSONArray().put(entry)
        for (i in 0 until log.length()) {
            merged.put(log.opt(i))
        }

        return store.edit()
            .putString(KEY_WATER_LOG, merged.toString())
            .putBoolean(KEY_PENDING_REFRESH, true)
            .commit()
    }

    // --- Medicines -----------------------------------------------------------

    /** One scheduled dose on today's plan. */
    data class Dose(
        val medicineId: String,
        val name: String,
        val hour: Int,
        val minute: Int,
        val taken: Boolean,
        /**
         * Whether anything at all has been logged against this slot, taken or
         * skipped. Kept apart from [taken] so a dose the user deliberately
         * skipped stops being offered without being counted as swallowed.
         */
        val settled: Boolean,
    ) {
        val minuteOfDay: Int get() = hour * 60 + minute
    }

    /**
     * An intake read off today's log, before it has been matched to a slot.
     *
     * Held to the second, not the minute, because the gap test has to truncate the
     * same way Dart's `Duration.inMinutes` does. An intake 180 min 30 s before a
     * slot is inside the app's window and would be outside a minute-rounded one,
     * and then the widget's count would disagree with the day view.
     */
    private class Mark(val secondOfDay: Int, val skipped: Boolean)

    /**
     * Today's scheduled doses in clock order, each matched to the intake that
     * settles it, if any.
     *
     * Matching mirrors the app's `TimelineService`: every intake claims the
     * nearest slot still free, and each slot can be claimed only once. The
     * simpler "is any intake within three hours" test looks equivalent and is
     * not — on an hourly schedule a single tap sits within three hours of seven
     * slots, so one dose would silently settle a whole afternoon and the count
     * in the corner would jump by seven.
     */
    fun dosesToday(context: Context): List<Dose> {
        val store = prefs(context)
        val now = Calendar.getInstance()
        val today = dayKey(now)
        val weekday = dartWeekday(now)

        val logged = mutableMapOf<String, MutableList<Mark>>()
        val log = readArray(store.getString(KEY_MEDICINE_LOG, null))
        for (i in 0 until log.length()) {
            val intake = log.optJSONObject(i) ?: continue
            val stamp = intake.optString("timestamp")
            if (dayKeyOfIso(stamp) != today) continue
            val id = intake.optString("medicineId")
            if (id.isEmpty()) continue
            val second = secondOfDayOfIso(stamp) ?: continue
            logged.getOrPut(id) { mutableListOf() }
                .add(Mark(second, intake.optBoolean("skipped", false)))
        }

        val doses = mutableListOf<Dose>()
        val medicines = readArray(store.getString(KEY_MEDICINES, null))
        for (i in 0 until medicines.length()) {
            val medicine = medicines.optJSONObject(i) ?: continue
            // Matches Dart's `json['enabled'] != false`, so a payload written
            // before the flag existed still counts as on.
            if (medicine.optBoolean("enabled", true).not()) continue

            val days = medicine.optJSONArray("weekdays") ?: continue
            var dueToday = false
            for (d in 0 until days.length()) {
                if (days.optInt(d, -1) == weekday) {
                    dueToday = true
                    break
                }
            }
            if (!dueToday) continue

            val id = medicine.optString("id")
            // Dropped rather than given a placeholder name: `Medicine.tryFromJson`
            // discards a nameless record outright, so keeping one here would put
            // slots in the widget's count that the day view has never heard of.
            val name = medicine.optString("name").trim()
            if (id.isEmpty() || name.isEmpty()) continue
            val times = medicine.optJSONArray("times") ?: continue

            val slots = mutableListOf<Int>()
            for (t in 0 until times.length()) {
                val parsed = parseHhMm(times.optString(t)) ?: continue
                slots.add(parsed.first * 60 + parsed.second)
            }
            if (slots.isEmpty()) continue
            slots.sort()

            // Earliest intake first, so the morning tablet claims the morning
            // slot even when two slots are within reach of both intakes.
            val marks = (logged[id] ?: mutableListOf()).sortedBy { it.secondOfDay }
            val claim = arrayOfNulls<Mark>(slots.size)
            for (mark in marks) {
                var best = -1
                var bestGap = Int.MAX_VALUE
                for (s in slots.indices) {
                    if (claim[s] != null) continue
                    // Whole seconds of distance, then truncated to minutes — the
                    // integer division mirrors `Duration.inMinutes` on the Dart side.
                    val gap = kotlin.math.abs(mark.secondOfDay - slots[s] * 60) / 60
                    if (gap <= GRACE_MINUTES && gap < bestGap) {
                        best = s
                        bestGap = gap
                    }
                }
                // An intake with no slot within reach is an extra dose. The app's
                // timeline shows those as their own row; a widget has nowhere to put
                // one, so it is simply not allowed to settle a scheduled slot.
                if (best >= 0) claim[best] = mark
            }

            for (s in slots.indices) {
                val settledBy = claim[s]
                doses.add(
                    Dose(
                        medicineId = id,
                        name = name,
                        hour = slots[s] / 60,
                        minute = slots[s] % 60,
                        taken = settledBy != null && !settledBy.skipped,
                        settled = settledBy != null,
                    )
                )
            }
        }

        doses.sortBy { it.minuteOfDay }
        return doses
    }

    /**
     * The dose to put on the widget: the first one nothing has been logged
     * against, whether or not its time has passed, because an overdue dose is
     * more worth showing than tomorrow's. Null when today's plan is settled.
     */
    fun nextDose(doses: List<Dose>): Dose? = doses.firstOrNull { !it.settled }

    fun recordTaken(context: Context, medicineId: String): Boolean {
        if (medicineId.isEmpty()) return false
        val store = prefs(context)
        val log = readArray(store.getString(KEY_MEDICINE_LOG, null))

        val intake = JSONObject()
            .put("medicineId", medicineId)
            .put("timestamp", isoLocal(Calendar.getInstance()))
            .put("skipped", false)

        val merged = JSONArray().put(intake)
        for (i in 0 until log.length()) {
            merged.put(log.opt(i))
        }

        return store.edit()
            .putString(KEY_MEDICINE_LOG, merged.toString())
            .putBoolean(KEY_PENDING_REFRESH, true)
            .commit()
    }

    // --- helpers -------------------------------------------------------------

    /**
     * Same three hours the app's timeline allows between a slot and its intake.
     * Not private: the medicine widget needs it to decide whether a tap on "Taken"
     * would actually settle the dose on screen.
     */
    const val GRACE_MINUTES = 180

    private fun readArray(raw: String?): JSONArray =
        if (raw.isNullOrEmpty()) JSONArray() else try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }

    private fun readObject(raw: String?): JSONObject =
        if (raw.isNullOrEmpty()) JSONObject() else try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }

    /**
     * `yyyy-MM-dd` in local time — the bucket key `WaterEntry.dayKeyFor` builds.
     *
     * [Locale.US] is not optional here. `String.format` with the default locale
     * renders `%d` in that locale's own digits, so on a device set to Hindi or
     * Arabic this would produce a key Dart could never match, and a widget
     * permanently reading zero.
     */
    private fun dayKey(calendar: Calendar): String = String.format(
        Locale.US,
        "%04d-%02d-%02d",
        calendar.get(Calendar.YEAR),
        calendar.get(Calendar.MONTH) + 1,
        calendar.get(Calendar.DAY_OF_MONTH),
    )

    /**
     * Whether a timestamp names its own zone, i.e. `...Z` or `...+05:30`.
     *
     * The app itself never writes one: `DateTime.toIso8601String()` on a local
     * `DateTime` is naive, so the common path is a plain slice. But a restored
     * backup can hold a zoned value — `DateTime.tryParse` turns `...Z` into a UTC
     * `DateTime` and `toJson` writes the `Z` straight back out. Dart copes
     * because `dayKeyFor` calls `toLocal()` first; slicing does not, and would
     * file a late-evening drink under the wrong day.
     */
    private fun hasZone(iso: String): Boolean {
        // From index 10 on purpose: everything before it is the date, whose own
        // hyphens are not offsets. `DateTime.tryParse` accepts a space in place of
        // the 'T', so neither separator is assumed.
        if (iso.length <= 10) return false
        return iso.indexOf('Z', 10) >= 0 ||
            iso.indexOf('+', 10) >= 0 ||
            iso.indexOf('-', 10) >= 0
    }

    /**
     * The timestamp re-expressed in the device's own zone, or null if it cannot
     * be read. Only walked for zoned input — see [hasZone].
     */
    private fun localOfZonedIso(iso: String): Calendar? {
        if (iso.length < 16) return null
        // Anything that is not `yyyy-MM-dd` then a separator is not a shape this
        // understands, and guessing would be worse than skipping the entry.
        if (iso[10] != 'T' && iso[10] != ' ') return null
        val time = 10

        val year = iso.substring(0, 4).toIntOrNull() ?: return null
        val month = iso.substring(5, 7).toIntOrNull() ?: return null
        val day = iso.substring(8, 10).toIntOrNull() ?: return null
        val hour = iso.substring(11, 13).toIntOrNull() ?: return null
        val minute = iso.substring(14, 16).toIntOrNull() ?: return null
        // Seconds are optional, and the character after the minutes is a ':' only
        // when they are present — otherwise it is the offset, whose hours would be
        // read as seconds.
        val second = if (iso.length >= 19 && iso[16] == ':') {
            iso.substring(17, 19).toIntOrNull() ?: 0
        } else {
            0
        }

        var offset = 0
        val plus = iso.indexOf('+', time)
        val sign = if (plus >= 0) plus else iso.indexOf('-', time)
        if (sign >= 0 && iso.length >= sign + 3) {
            val hours = iso.substring(sign + 1, sign + 3).toIntOrNull() ?: 0
            // Both spellings are legal ISO-8601: "+05:30" and "+0530".
            val minutes = when {
                iso.length >= sign + 6 && iso[sign + 3] == ':' ->
                    iso.substring(sign + 4, sign + 6).toIntOrNull() ?: 0
                iso.length >= sign + 5 ->
                    iso.substring(sign + 3, sign + 5).toIntOrNull() ?: 0
                else -> 0
            }
            offset = (hours * 60 + minutes) * if (iso[sign] == '-') -1 else 1
        }

        // Build the instant in UTC, then read it back through a default-zone
        // Calendar, which is what applies the device's offset and any DST rule.
        val utc = Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC"))
        utc.clear()
        utc.set(year, month - 1, day, hour, minute, second)
        utc.add(Calendar.MINUTE, -offset)

        val local = Calendar.getInstance()
        local.timeInMillis = utc.timeInMillis
        return local
    }

    /**
     * `yyyy-MM-dd` in local time for a stored timestamp — the bucket key
     * `WaterEntry.dayKeyFor` builds. Slicing on the common naive path keeps this
     * allocation-free; a zoned value takes the conversion.
     */
    private fun dayKeyOfIso(iso: String?): String? {
        if (iso == null || iso.length < 10) return null
        if (!hasZone(iso)) return iso.substring(0, 10)
        return localOfZonedIso(iso)?.let { dayKey(it) }
    }

    /** Seconds since local midnight for a stored timestamp. */
    private fun secondOfDayOfIso(iso: String?): Int? {
        if (iso == null || iso.length < 16) return null
        if (hasZone(iso)) {
            val local = localOfZonedIso(iso) ?: return null
            return local.get(Calendar.HOUR_OF_DAY) * 3600 +
                local.get(Calendar.MINUTE) * 60 +
                local.get(Calendar.SECOND)
        }
        val hour = iso.substring(11, 13).toIntOrNull() ?: return null
        val minute = iso.substring(14, 16).toIntOrNull() ?: return null
        val second = if (iso.length >= 19 && iso[16] == ':') {
            iso.substring(17, 19).toIntOrNull() ?: 0
        } else {
            0
        }
        return hour * 3600 + minute * 60 + second
    }

    /**
     * Local time in the naive ISO-8601 shape Dart's `tryFromJson` accepts.
     * [Locale.US] for the same digit-rendering reason as [dayKey] — a timestamp
     * in non-ASCII digits fails `DateTime.tryParse`, and the entry would be
     * dropped on the next load.
     */
    private fun isoLocal(calendar: Calendar): String = String.format(
        Locale.US,
        "%04d-%02d-%02dT%02d:%02d:%02d.%03d",
        calendar.get(Calendar.YEAR),
        calendar.get(Calendar.MONTH) + 1,
        calendar.get(Calendar.DAY_OF_MONTH),
        calendar.get(Calendar.HOUR_OF_DAY),
        calendar.get(Calendar.MINUTE),
        calendar.get(Calendar.SECOND),
        calendar.get(Calendar.MILLISECOND),
    )

    /**
     * Dart's `DateTime.weekday` is 1 = Monday .. 7 = Sunday; [Calendar] uses
     * 1 = Sunday .. 7 = Saturday. Getting this wrong shifts every medicine
     * schedule by a day, and on Sundays would hide them entirely.
     */
    private fun dartWeekday(calendar: Calendar): Int =
        when (calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY -> 1
            Calendar.TUESDAY -> 2
            Calendar.WEDNESDAY -> 3
            Calendar.THURSDAY -> 4
            Calendar.FRIDAY -> 5
            Calendar.SATURDAY -> 6
            else -> 7
        }

    /** `"HH:mm"`, as written by the `hhmm` extension on the Dart side. */
    private fun parseHhMm(value: String?): Pair<Int, Int>? {
        if (value == null) return null
        val parts = value.split(":")
        if (parts.size != 2) return null
        val hour = parts[0].toIntOrNull() ?: return null
        val minute = parts[1].toIntOrNull() ?: return null
        if (hour !in 0..23 || minute !in 0..59) return null
        return Pair(hour, minute)
    }
}
