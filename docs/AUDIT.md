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

## Re-audit: text over photographic wallpapers (2026-10-21)

The wallpapers changed from generated colour fields to Google TV's ambient
photographs, so every surface that composites straight onto the wallpaper was
re-checked against the **worst case**: `background1`, whose pale sky is the
brightest thing in the collection, forced as the only wallpaper.

1. **Header text washed out.** Over the pale sky the greeting and date were
   unreadable and the clock was marginal — blur does nothing for contrast here,
   because a photograph blurs to a *bright* field at the sky, not a dark one.
   Fixed with `scrim_reading`, a soft radial vignette anchored on the header's
   corner (`drawable-ldrtl/` carries the mirrored twin for the RTL layout).
   Re-checked over the same worst case: all three lines readable, no hard edge,
   photo still visible.
2. **`Connected` in the focused input row was too pale.** `pill_text_dim` used
   `#99111111` — 60% black — for the focused state, which is fine on a dark panel
   and nearly invisible on the white focused pill, at 11sp. Not a wallpaper
   problem; found because the check widened to every overlay. Now `#CC111111`
   focused, and the unfocused `#73FFFFFF` raised to `#99FFFFFF` for the same
   reason on dark panels.
3. **Surfaces with their own background are unaffected** — dock tiles, app cards,
   popup panels and dialogs sit on opaque or near-opaque surfaces, so the
   wallpaper cannot reach their text.
4. **Blur strength was wrong for photographs.** The decode-time blur shrank to
   1/8, which reduces a photograph to a colour field. Reduced to 1/4: the subject
   still reads, and contrast is handled by the dim layer and the vignette.

## The restart button: what works, and the part that cannot

A restart icon sits beside Settings, with a Yes/No confirmation (No focused by
default). The dialog, the D-pad handling and the focus return all work. **The
system restart itself is not possible from an app installed from an APK on this
set**, and that is a platform rule, not a defect in this code:

- `android.permission.REBOOT` is `signature|privileged`; `pm grant` refuses
  signature permissions.
- No root: locked bootloader, verified boot green, no `su`.
- Device owner is ruled out — `dpm set-device-owner` needs a device with **no
  accounts**, and this one has three Google accounts.
- `ACTION_REBOOT` resolves to the framework's `ShutdownActivity`, and from a
  normal app it is **accepted and then silently does nothing** — measured: no
  restart, no exception, not even a log line. That silence is why it is unused.
- `PowerManager.reboot()` at least fails honestly: `SecurityException`. Measured
  end to end — the launcher's pid changed 3808 → 4030 while `/proc/uptime` kept
  climbing, which proves the refusal and the fallback both ran.

So the button **restarts Home**, and the dialog says exactly that. A full system
restart is still the remote: long-press power for the power menu.

One bug this surfaced: after a dialog dismisses, the activity's saved focus beats
`requestFocus()`, so focus landed on a tile and the next Enter launched an app.
Focus is now restored from `setOnDismissListener` on a short post.

## Following the ambient artwork (2026-10-21)

Google TV's screensaver downloads its artwork and rotates it on Google's own
schedule. The pictures live in a `DiskLruCache` at

```
/sdcard/Android/data/com.google.android.apps.tv.dreamx/files/Pictures/cache/
```

content-addressed by SHA-256 with a `.0` suffix, plus a `journal`. At the time of
measurement it held **17 entries (4 MB)**, of which **16 were unique 1920×1080
WEBP pictures not present in the APK's own 10 bundled assets** — so it really does
refresh, and reading it is the only way to follow along.

**An app cannot read that directory.** Measured from the launcher's own uid:

```
uid=10061  exists=true  isDir=true  canRead=false  canExecute=true  listFiles=NULL
```

That is *with* `MANAGE_EXTERNAL_STORAGE` granted (`appops set ... allow`). Android 11
keeps `Android/data/<pkg>` sealed per app; All-files-access lifts the scoped-storage
restriction on shared storage, not this one. The directory mode is `771` (other gets
execute but not read) and the files are `660` in group `sdcard_rw` — which is
exactly why **adb shell can read it and an app cannot**: `shell` is in `sdcard_rw`.

So the bridge is the host, not the app. `tools/sync-ambient.sh` runs a small script
on the TV (`shell sh -s`), copies new pictures into the collection and deletes
copies of pictures the cache has evicted. Measured: first run `16 added, 0 retired`;
repeat runs `0 added, 0 retired, 16 unchanged` (idempotent); deleting a copy
restores it; an invented `ambient-deadbeef.webp` is retired. The launcher rescans
its own collection on each rotation, so it needs no restart.

`AmbientMirror.java` was written and then deleted: it worked as designed but the
platform refuses the read, so keeping it would have been dead code behind a
permission that does not help.

One environment note that cost time here: **logcat is empty on this set** (`logcat
-d` returns 0 lines), so `Log.w` is useless for diagnosis. The uid/permission
question above was answered by having the app write a status file into its own
directory and reading that back.

## Sharp artwork (2026-10-21)

Seen live, the background was "a blurry mess" — correct, and it was our doing. The
decode-time blur shrank each 1080p picture to 480×270 and scaled it back up, which
on a 1080p display is nothing but lost detail. It is now **off by default**, and the
pictures decode in 32-bit colour instead of RGB_565.

Measured A/B: same wallpaper, only `wallpaper_soften` in `config.json` toggled.

| | blur on | blur off |
|---|---|---|
| edge energy, background crop | 0.53 | **5.57** (10.5×) |
| screenshot PNG | 1.27 MB | **3.10 MB** |
| region brightness | 57.2 | 57.7 |
| on/off correlation | 0.998 — the same scene, so only detail differs | |

Cost: PSS settles at ~62 MB instead of ~41 MB, because the displayed bitmap is now a
full-resolution ARGB_8888 frame rather than a half-megabyte thumbnail. Against
454–467 MB available that is affordable. `wallpaper_soften` keeps the old look one
config push away.

Two things this taught:

1. **Judge sharpness on a 1:1 crop, never the full frame.** The full screenshot —
   and any viewer that downscales it — reads as soft even when the pixels are
   crisp; at native resolution the fur texture is plainly there. Google's ambient
   art also includes shallow-depth-of-field photographs that look soft *by design*,
   which is easy to mistake for our blur still being on.
2. **`push-theme.sh` deleted the entire synced ambient set once.** Its stale-image
   sweep compares the TV's collection against `theme/wallpapers/`, and the mirrored
   pictures exist only on the TV, so all 16 counted as stale and were removed. It now
   skips the `ambient-` prefix, which `sync-ambient.sh` owns and prunes itself.
