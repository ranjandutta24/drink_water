import '../models/volume_unit.dart';
import '../models/water_settings.dart';

/// Formats millilitres in whichever unit the user chose. Storage always stays
/// in ml so switching units never rewrites history.
String formatVolume(
  int ml,
  WaterSettings settings, {
  bool withUnit = true,
  bool compact = false,
}) {
  switch (settings.displayUnit) {
    case VolumeUnit.ml:
      return withUnit ? '$ml ml' : '$ml';
    case VolumeUnit.liter:
      final litres = ml / 1000;
      final text = _trim(litres, litres < 10 ? 2 : 1);
      return withUnit ? '$text L' : text;
    case VolumeUnit.glass:
      final size = settings.glassSizeMl <= 0 ? 250 : settings.glassSizeMl;
      final count = ml / size;
      final text = _trim(count, 1);
      if (!withUnit) return text;
      if (compact) return '$text gl';
      return '$text ${count == 1 ? 'glass' : 'glasses'}';
    case VolumeUnit.bottle:
      final size = settings.bottleSizeMl <= 0 ? 750 : settings.bottleSizeMl;
      final count = ml / size;
      final text = _trim(count, 1);
      if (!withUnit) return text;
      if (compact) return '$text btl';
      return '$text ${count == 1 ? 'bottle' : 'bottles'}';
  }
}

/// The unit suffix on its own, for pairing with a big numeral.
String unitSuffix(WaterSettings settings) {
  switch (settings.displayUnit) {
    case VolumeUnit.ml:
      return 'ml';
    case VolumeUnit.liter:
      return 'L';
    case VolumeUnit.glass:
      return 'glasses';
    case VolumeUnit.bottle:
      return 'bottles';
  }
}

/// Short label used on quick-add buttons and chart axes.
String formatVolumeCompact(int ml, WaterSettings settings) =>
    formatVolume(ml, settings, compact: true);

String _trim(double value, int decimals) {
  var text = value.toStringAsFixed(decimals);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

/// "1 h 30 m" style duration, used for the reminder interval.
String formatInterval(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
  return '${hours}h ${rest}m';
}

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String weekdayShort(DateTime date) => _weekdayShort[date.weekday - 1];

String monthShort(DateTime date) => _monthShort[date.month - 1];

String formatDayLabel(DateTime date) {
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  if (isToday) return 'Today';
  final yesterday = now.subtract(const Duration(days: 1));
  if (date.year == yesterday.year &&
      date.month == yesterday.month &&
      date.day == yesterday.day) {
    return 'Yesterday';
  }
  return '${weekdayShort(date)} ${date.day} ${monthShort(date)}';
}

String formatClock(DateTime time, {bool use24h = false}) {
  if (use24h) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
  final period = time.hour < 12 ? 'am' : 'pm';
  var hour = time.hour % 12;
  if (hour == 0) hour = 12;
  return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
}
