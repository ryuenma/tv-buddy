# tv-buddy

A lightweight replacement launcher for a **TCL Smart TV Pro**, built for a
low-spec 2 GB Android TV and aimed at one specific complaint: the TV lags and
crashes under the stock Google TV launcher and TCL's background services.

The Home screen is deliberately small: her apps, the TV's inputs, a clock, and a
rotating wallpaper. No sponsored rows, no content feeds.

## Target device

| | |
|---|---|
| Model | TCL Smart TV Pro / `BeyondTV4` / `G03_4K_GB` |
| SoC | Realtek `RTD2851M` (`rtd288o`), **Mali-G31**, GLES 3.2 |
| OS | Android **11**, API **30**, build `AR09` |
| RAM | 2 GB (measured ~500 MB swap in use at rest) |
| ABI | `armeabi-v7a` only — no arm64 |
| Display | 1920×1080 @ 320 dpi |
| Root | **No.** Locked bootloader, verified boot green, no `su` |

Everything here is unrooted: install, verify, then switch the HOME component.
Nothing is uninstalled and every change is reversible.

## Status

| Area | State |
|---|---|
| Release build | ✅ 418,635 B, R8 + `shrinkResources` |
| Install as a normal app | ✅ verified |
| Renders on device | ✅ clock, greeting, docks, quick pills |
| D-pad navigation | ✅ verified |
| Inputs menu | ✅ HDMI 1–3 · AV · **Live TV** |
| HDMI 4 | ❌ not offered — see *Known limits* |
| **Used as HOME** | ✅ **stock launcher disabled, survives reboot** |
| **Wallpaper + blur** | ✅ rotating abstract set, blurred once at decode |
| Festival/cultural extras | ✅ removed (1,820 lines deleted) |
| Debloat | ✅ 26 packages disabled, swap down 89% |
| Remote/HDMI/audio verification | ⏳ needs a human with the remote |

## Upstream and our changes

Vendored from **https://github.com/Gathin23/cleanyourtv** (MIT), commit
`3e996739ce0b470b51c1c438bf5d0559d1c9e7eb`, directory `launcher/`.
Only `launcher/` is vendored — the rest of that repo (docs, examples, install
scripts) is not part of this project.

Local changes so far, all in `launcher/app/src/main/res/values/config.xml`:

- `live_tv_package`: `com.mediatek.wwtv.tvcenter` → **`com.tcl.tv`**
  Upstream defaults to MediaTek's TV Centre. This TV is Realtek, so the package
  does not exist, `liveTvIntent()` returned null, and the Inputs menu silently
  omitted the Live TV row.
- `hidden_apps`: `com.mediatek.wwtv.tvcenter` → **`com.tcl.tv`**, so the Live TV
  app does not also appear as a duplicate tile.

> Upstream is active (that commit is from the same day this project started).
> Re-pin deliberately, diff against this file, and re-verify the Inputs menu
> after any bump.

## Build

Needs JDK 17+ (tested on Temurin 21) and Android SDK platform 34 +
build-tools. No extra Gradle install — the wrapper fetches 8.9.

```bash
export JAVA_HOME="F:/Tools/jdk-21.0.12.1+1"
export ANDROID_HOME="F:/Android Emulator/sdk"
cd launcher
./gradlew.bat assembleRelease
```

Output: `launcher/app/build/outputs/apk/release/app-release.apk`

The release build signs with the **debug** key on purpose (sideloaded over adb,
never published), so rebuilds install over each other. Keep a stable keystore if
that ever needs to change.

## Install and verify

Deploy in this order. Do not skip to step 4.

```bash
ADB="F:/Android Emulator/sdk/platform-tools/adb.exe"
D="-s <TV_IP>:5555"

# 0. The dreamx screensaver steals the screen when idle — always wake first
"$ADB" $D shell input keyevent KEYCODE_WAKEUP

# 1. Install alongside, without touching HOME
"$ADB" $D install -r launcher/app/build/outputs/apk/release/app-release.apk

# 2. Launch and look at it
"$ADB" $D shell am start -n com.gathin.tvhome/.MainActivity

# 3. Verify: D-pad focus, Inputs lists Live TV, Settings pill, app library
#    (confirm HOME is still Google TV before continuing:)
"$ADB" $D shell cmd package resolve-activity -a android.intent.action.MAIN \
  -c android.intent.category.HOME | grep packageName

# 4. Only once step 3 passes — switch HOME
"$ADB" $D shell cmd package set-home-activity com.gathin.tvhome/.MainActivity
```

Rollback, at any time:

```bash
# back to Google TV
"$ADB" $D shell cmd package set-home-activity \
  com.google.android.apps.tv.launcherx/.home.HomeActivity

# or the AOSP TV safety net
"$ADB" $D shell cmd package set-home-activity \
  com.android.tv.settings/.system.FallbackHome
```

## Known limits

**HDMI 4 cannot be offered.** The hardware port exists
(`TvInputHardwareInfo{id=1413745664, type=9, hdmi_port=4}`) but TCL's
`TIF_TvInput` never registered a `TvInputInfo` for it — it appears only as
hardware, never as an input. Ports 1–3 are registered. The stock Google TV
launcher reads the same `TvInputManager` API and cannot offer it either. A
vendor-intent workaround may exist (`com.tcl.settings.SHOW_WINDOW`); unverified.

**No Liquid Glass.** Real Liquid Glass needs backdrop sampling through
`RuntimeShader` (**API 33**) or `RenderEffect` (**API 31**). This TV is API 30,
so neither exists. Every popular Liquid Glass library degrades to a flat scrim or
draws nothing here (`QmDeve/AndroidLiquidGlassView` renders *nothing* below
Android 13). The plan is pre-computed CPU glass: blur the wallpaper once per
rotation, then composite panels over it — zero per-frame GPU cost, which matters
on a Mali-G31.

**The launcher alone will not fix the lag.** Measured PSS: 44 MB (ours) vs 87 MB
(`launcherx`), plus ~34 MB of `:coreservices` — about 76 MB saved, plus relief of
28 MB of swapped pages. The rest must come from disabling TCL's background
services; `com.tcl.bi` alone wakes a foreground service roughly every 30 seconds.

## Theme and wallpapers

The launcher reads a small theme directory **on the TV**, not from inside the APK:

```
/sdcard/Android/data/com.gathin.tvhome/files/
├── config.json
└── wallpapers/*.jpg
```

Push the checked-in set with:

```bash
ADB="F:/Android Emulator/sdk/platform-tools/adb.exe" sh tools/push-theme.sh 192.168.31.35
```

`theme/config.json` sets a 30-minute rotation with a 45% dim. Five abstract
wallpapers live in `theme/wallpapers/` (~20 KB each) and are regenerated by
`tools/make_wallpapers.py`.

**Why they are abstract, and why they are blurred:** Android 11 has no
`RenderEffect` (API 31) and no AGSL (API 33), so a backdrop blur cannot be done at
render time on this TV. `WallpaperPlayer` instead blurs each picture **once, at
decode time** — shrink to 1/8, one box-blur pass per axis, then let the
`ImageView` scale it back up with filtering. Zero per-frame GPU cost, which is the
whole point on a Mali-G31. The result reads as soft ambient colour behind the
glass panels instead of a sharp photo fighting them.

Consequence worth knowing: **any wallpaper you add is softened deliberately.** A
family photo will come out as a blurred colour field, not a picture. That is the
design, not a bug.

## Docs

- `docs/RECON-LEDGER.md` — every measured fact about the device, evidence-tagged
- `docs/DECISIONS.md` — the kickoff decisions, findings, and verification log
- `docs/img/inputs-fixed.png` — the Inputs menu with Live TV present

## License and attribution

The vendored launcher is MIT, © 2026 Gathin — full text in
`licenses/cleanyourtv-MIT.txt`. The Outfit typeface shipped in
`launcher/app/src/main/res/font/` is under the SIL Open Font License, see
`launcher/FONT-LICENSE-OFL.txt`.

Treat the stock Google TV launcher strictly as a read-only oracle. Do not copy
its compiled code into this project.
