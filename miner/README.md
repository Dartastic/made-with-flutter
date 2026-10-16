# Made With Flutter miner

Finds which popular Play Store apps are made with Flutter by driving a real
Android phone over adb. It is the bulk companion to the Made With Flutter app
(the app scans what is already on a phone; the miner fills the phone).

For each app, most-installed first, it:

1. opens the app's Play Store page on the phone and taps **Install**,
2. waits for the package manager to report it,
3. inspects its APKs (base + splits) the same way the app's
   `FlutterAppInspector` does: `libflutter.so` present = Flutter, plus
   `libapp.so`, `flutter_assets` and the Dart VM version embedded in
   `libflutter.so`,
4. appends the verdict to `out/results.jsonl`,
5. uninstalls the app again (unless `--keep`; apps that were already on the
   phone are never uninstalled).

## Needs

- One Android phone on USB with debugging on, signed in to the Play Store,
  screen unlocked (the miner taps the Play Store UI).
- `adb` from the Android SDK (found via `ANDROID_HOME` or
  `~/Library/Android/sdk`), Dart ≥ 3.12.

## Use

```sh
dart pub get

# Inspect apps already on the phone.
dart run bin/miner.dart check com.wendys.nutritiontool com.google.earth

# Rank: harvest ids from Play top charts + every app category page, fetch
# each app's exact install count, write out/ranked.json most-installed first.
dart run bin/miner.dart rank

# Mine the top 50 (resumable: ids already in out/results.jsonl are skipped).
dart run bin/miner.dart mine --limit 50

# Or mine specific apps.
dart run bin/miner.dart mine com.philips.lighting.hue2
```

## Known Flutter apps used to validate detection

| App          | Package                                          | Verdict (2026-10-16)     |
|--------------|--------------------------------------------------|--------------------------|
| Wendy's      | `com.wendys.nutritiontool`                       | Flutter, Dart 3.12.2     |
| TAP Portugal | `com.megasis.android`                            | Flutter, Dart 3.3.4      |
| SNCF Connect | `com.vsct.vsc.mobile.horaireetresa.android`      | Flutter, Dart 3.11.5     |
| NotebookLM   | `com.google.android.apps.labs.language.tailwind` | Flutter, Dart 3.14.0-dev |
| Google Earth | `com.google.earth`                               | Flutter, Dart 3.14.0-dev |
| Philips Hue  | `com.philips.lighting.hue2`                      | Flutter, Dart 3.13.2     |
| Frontier     | `com.flyfrontier.android`                        | Not Flutter (3.7.8)      |

Google's own apps (Earth, NotebookLM, GPay, Play Console) ship
`libflutter.so` without `libapp.so` or `flutter_assets`, so only
`libflutter.so` decides the verdict. Frontier 3.7.8 ships no Flutter engine
(its APK carries Compose name mappings).

## Limits

- Paid, region-locked and device-incompatible apps are recorded as
  `notOffered` and skipped.
- "Popular" means the union of the Play top charts and category pages for
  one country (`--country`, default US), ordered by exact install count.
  Games are excluded.
