/// How the user prefers to see and enter water volumes.
///
/// Everything is stored internally in millilitres; the unit only affects
/// display and the quick-add buttons. That keeps reports and imports
/// consistent even if the user switches units later.
enum VolumeUnit {
  ml('ml', 'Millilitres'),
  liter('L', 'Litres'),
  glass('glass', 'Glasses'),
  bottle('bottle', 'Bottles');

  const VolumeUnit(this.shortLabel, this.longLabel);

  final String shortLabel;
  final String longLabel;

  static VolumeUnit fromName(String? name) {
    return VolumeUnit.values.firstWhere(
      (unit) => unit.name == name,
      orElse: () => VolumeUnit.ml,
    );
  }
}
