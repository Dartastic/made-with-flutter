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

# Mine specific apps.
dart run bin/miner.dart mine com.philips.lighting.hue2
```

## Lists: one per country

Each country has its own list, `out/ranked-<cc>.json` (`ranked-us.json`,
`ranked-de.json`, ...), most-installed first. Lists are separate because
the phone's Play account decides what it may install: mine a country's list
only while the phone is signed in to an account for that country.

Two commands fill a list, and both only ever add to it:

```sh
# Top charts + every app category page of each country.
dart run bin/miner.dart rank --country DE,FR,GB,IT,ES,NL,PL,PT

# Play search: terms/en.txt plus the country's language list
# (terms/de.txt, fr, it, es, nl, pl, pt). Keeps apps with at least
# 1,000,000 installs; change with --min-installs.
dart run bin/miner.dart search --country DE,FR,GB,IT,ES,NL,PL,PT
```

Search finds far more apps than the charts (up to 30 per term). Add terms
to the `terms/*.txt` files, or pass your own list with `--terms <file>`.
Install counts are worldwide, so the same app ranks the same everywhere.

All countries write their verdicts to one `out/results.jsonl`. An app
already checked in any country is skipped in every other, so overlapping
lists cost nothing.

## Overnight runs on the phone

1. Switch the phone's Play Store to the account for the country you will
   mine (e.g. your Europe account for `de`, `fr`, ...).
2. Unlock the phone and plug it in.
3. Run, for one country's list:

   ```sh
   ./mine-overnight.sh --country DE
   ```

   It keeps the screen on while plugged in, mines every app in
   `out/ranked-de.json` not yet in `out/results.jsonl`, restores the screen
   settings, and prints the Flutter table. The log goes to
   `out/overnight-<date>.log`. With several phones connected, set
   `MWF_SERIAL=<serial>`.
4. In the morning, or any time:

   ```sh
   ./print-flutter-table.sh
   ```

   (`filter-flutter-in-out-json.sh` writes the Flutter rows to
   `flutter_apps2.json`; the table script runs it first.)

The miner stops by itself, instead of recording false verdicts, when the
phone gets unhealthy: unplugged, Play Store signed out, screen unreadable,
or 5 failed installs in a row. Fix the phone and rerun the same command;
it resumes where it stopped. After a "5 failed installs" stop, first delete
those last 5 rows from `out/results.jsonl` so they are tried again.

When a run finishes with nothing to do, that country's list is used up:
grow it with `search` (more terms) or move to another country.

## Mining on the emulator instead of a phone

`mwf-miner` is an Android 15 Google Play arm64 emulator (8 GB data
partition; the miner uninstalls as it goes). Create it once:

```sh
sdkmanager "system-images;android-35;google_apis_playstore;arm64-v8a"
avdmanager create avd -n mwf-miner -d pixel_8_pro \
  -k "system-images;android-35;google_apis_playstore;arm64-v8a"
# in ~/.android/avd/mwf-miner.avd/config.ini:
#   PlayStore.enabled=yes  hw.keyboard=yes  disk.dataPartition.size=8G
```

Then:

```sh
./start-emulator.sh          # boots it, keeps the screen on
# first time: sign in to the Play Store in the emulator window
dart run bin/miner.dart mine --serial emulator-5554 --limit 100
```

Pass `--serial` whenever a phone is plugged in too. Some apps refuse to
install on emulators; those are recorded as `notOffered`.

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
- A list is what Play shows for one country (charts, category pages,
  search results), ordered by worldwide install count; it is not a complete
  ranking of all apps. Games are excluded from the category pages.
