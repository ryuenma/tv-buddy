# Repo audit — tv-buddy

Run 2026-10-21 with the `ponytail-audit` pass over the whole repo.

**Load assumed:** one household, one TV, one Home key press at a time. A single
user process with no network service, no concurrency and no untrusted input
beyond the apps already installed on the TV. Every judgement below is against
that, not against server scale.

**Scope:** 162 tracked files. 33 Java sources in `launcher/`, 17 JVM test files,
`tools/` (2), `theme/` (6), `docs/` (5).

---

## Fixes applied

### 1. The test suite was broken, and the release build could not see it

`assembleRelease` never compiles unit tests. My festive strip deleted
`Festival`, `RaceWeekend`, `Shamsi`, `DiyaDrawable`, `MarigoldDrawable`,
`PetalShowerView` and `BellDrawable`, and `FestivalTest` / `RaceWeekendTest`
still referenced them — so the app built, installed and ran while
`./gradlew testReleaseUnitTest` failed outright.

Removed both test files (they tested deleted features).
**Suite now: 125 tests, 0 failures.**

Lesson worth keeping: after deleting production classes, run the tests. A green
release build says nothing about the test sources.

### 2. Dead locals left behind by the strip

`updateWifiLabel()` still computed `flame` and `steady` — including a
`WifiManager.calculateSignalLevel()` call — for the festive diya's flame. Nothing
read them after the strip. Removed.

### 3. `ACCESS_FINE_LOCATION` was never granted

The manifest comment states *"build-and-install grants it with pm grant"*, but we
installed with plain `adb install`, so it was never granted and the Wi-Fi pill
could never show the network name — it would silently fall back to the generic
"Wi-Fi" label forever.

```bash
pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION
```

Verified `granted=true`, and it survives a reinstall.

### 4. The blur had no runnable check

Non-trivial arithmetic (5-sample window, edge clamping, forced opacity) with zero
coverage. Extracted the pixel maths out of `WallpaperPlayer` into a pure
`Blur.java` and added `BlurTest` pinning three cases: edge clamping and the
centre average (`0xFF666666`), forced opaque alpha, and a uniform field staying
unchanged. Counting the wallpaper size/type guards, `WallpaperRotationTest` and
`WallpaperSizeTest` already existed.

---

## Watch — not changed

### 5. A cropped second row shows below the dock

`rows_below_dock` is `0` and its own comment says *"0 = dock sits at the very
bottom"*, yet the top of grid row 2 is visible under the dock band.

Mechanism: the dock is row 1 of the `RecyclerView`. `AppAdapter.BOTTOM_ROOM_DP`
reserves roughly 40 dp below it so a scaled, focused tile cannot be clipped, and
that reserved strip is exactly the space row 2 draws into. Nothing is broken —
the reserve is deliberate — but it contradicts the documented layout.

Two ways out, both one-liners, opposite looks: drop the bottom reserve, or keep
it and accept the peek as a scroll affordance (several TV UIs do this on
purpose). Needs an owner decision, so I left it.

### 6. A dormant clock-screensaver subsystem

`ClockActivity`, `ClockDream` and `ClockScene` are declared and compiled, but the
active screensaver is Google's `dreamx` (owner decision 5), and
`home_idle_clock_minutes` is unset. They are reachable only if someone selects
them by hand in Settings → screensaver. Roughly 600 lines of dead weight of the
same kind the festive strip removed. Not removed here because it is a capability
question, not a defect.

### 7. `ThemeProvider` is an exported content provider — accepted

It can write files and (as a design goal) set secure settings. Two guards were
checked rather than assumed:

- `android:permission="android.permission.WRITE_SECURE_SETTINGS"` — a
  `signature|privileged` permission, so only shell/system can call it.
- `ThemeFiles.path()` whitelists exactly `config.json`, `wallpaper.jpg`,
  `theme_revision`, or `wallpapers/<name>` where `<name>` must match
  `[A-Za-z0-9_.-]+\.(jpg|jpeg|png|webp)`. No `/` can survive, so `../` traversal
  is not reachable.

Accepted for this threat model: the TV has third-party apps installed, but none
can hold that permission.

### 8. `WifiManager.getConnectionInfo()` is deprecated

Still functional on API 30 and the only way to read the SSID. Legacy, not broken.

---

## Checked and clean

- **Receiver registration:** 6 `registerReceiver` against 2 `unregisterReceiver`
  looks like a leak. It is not — they are an if/else pair for the API-33
  `RECEIVER_NOT_EXPORTED` overload, so only two run and both are unregistered in
  `onStop()`. The count was misleading; reading the sites resolved it.
- **Thread/executor lifetime:** `WallpaperPlayer` owns the only executor and
  `close()` calls `shutdownNow()`; `onDestroy()` calls `close()`.
- **Wallpaper input bounds:** `WallpaperRotation.images()` caps file size at
  10 MB, whitelists four extensions, stops at 100 images and sorts by filename
  for a stable order across restarts. `WallpaperSize.accepted()` guards decoded
  dimensions.
- **Swallowed exceptions:** eight `catch (… ignored)` sites, all deliberate
  "never take the Home screen down" guards on optional features (module cards,
  SSH/SSID reads, revision tokens). `CardFeature` reports its failure before
  disabling itself. Not silent-failure sloppiness.
- **Permission surface:** three permissions, all normal or ADB-grantable. No
  `QUERY_ALL_PACKAGES` — package visibility uses explicit `<queries>`.

---

## Not read

Roughly 20 UI/dialog files were inspected by grep and signature only, not read
line by line: `AppLibraryDialog`, `Cards`, `HeroArt`, `CardFeature` internals,
`QuickSettingsActivity`, `LauncherSettingsActivity`, `HomeSettingsActivity`,
`VpnBadge`, `GridNavigation`, `Order`, `LibraryApps`, `ClockScene`, `Sky`,
`SkyView`, `Sun`, `GlassView` internals, and `AppAdapter` beyond tile sizing and
the launch path.

The least-audited area is **`AppLibraryDialog` and the three settings
activities** — they handle focus, dismissal and preference writes, which is
exactly where a stuck-focus or lost-setting bug would live. If this repo grows,
audit those first.
