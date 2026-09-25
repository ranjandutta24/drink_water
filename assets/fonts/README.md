# Bundled typefaces

The font picker in Settings offers these families. Everything here is bundled
into the APK, so choosing a font never touches the network — that is the whole
reason the `google_fonts` package is not used.

Already in the repo:

| Family  | Files                                            | Licence          |
| ------- | ------------------------------------------------ | ---------------- |
| Play    | `Play-Regular.ttf`, `Play-Bold.ttf`              | `OFL.txt`        |
| Poppins | `Poppins-Regular.ttf`, `-Medium.ttf`, `-Bold.ttf`| `OFL-Poppins.txt`|

## Still to add: Plus Jakarta Sans, Inter, Manrope

`AppFont` already lists all three and the picker shows them, but their files
are not here yet. Until they are, picking one of them falls back to the phone's
own font — no crash, and the row's own preview text is the tell, because each
row is set in the family it offers.

To finish them:

1. Download each family from Google Fonts (`fonts.google.com/specimen/Inter`,
   `.../Manrope`, `.../Plus+Jakarta+Sans`). The download is a zip; the static
   instances are under `static/` inside it.
2. Copy exactly three weights per family into this folder, named as below. The
   names have to match, because `pubspec.yaml` refers to them literally.
   - `PlusJakartaSans-Regular.ttf`, `PlusJakartaSans-Medium.ttf`, `PlusJakartaSans-Bold.ttf`
   - `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-Bold.ttf`
   - `Manrope-Regular.ttf`, `Manrope-Medium.ttf`, `Manrope-Bold.ttf`
3. Copy each family's `OFL.txt` out of its zip and rename it
   `OFL-PlusJakartaSans.txt`, `OFL-Inter.txt`, `OFL-Manrope.txt`. All three are
   SIL Open Font License 1.1, which requires the licence to ship with the font.
4. In `pubspec.yaml`, uncomment that family's block under `flutter: fonts:`.
   Do not uncomment a block before its files are on disk — a declared asset
   that does not exist fails the build.
5. `flutter pub get` (the asset manifest is rebuilt from pubspec), then a full
   `flutter run`. Hot reload does not pick up new font assets.

Three weights rather than two: a lot of this app's text is `w600`, and with only
400 and 700 declared Flutter snaps it to one of those. The 500 gives it
something closer to aim at, so headings and figures keep their intended weight.

If you would rather not add all three, delete the ones you do not want from
`AppFont` in `lib/theme.dart` instead of leaving a row in the picker that does
nothing. `appFontFromName` is tolerant, so a backup that still names a removed
font loads as the default rather than failing.
