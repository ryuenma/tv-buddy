# TCL Smart TV Pro — Project Decisions

Kickoff interview held 2026-10-21 using the `grill-me` skill. Every decision below
was made by the owner in response to a specific question. Evidence tags match the
recon ledger: [O] observed on the live device.

## Decisions

| # | Decision | Chosen | Why |
|---|---|---|---|
| 1 | Primary purpose | **Clean + fast Home** — her apps, TV inputs, a clock, rotating wallpapers | Owner's words: main user is his mother; she complains the TV lags and crashes |
| 2 | Scope | **Launcher is a must.** Debloat is a separate deliverable | Owner: "give me a full list later... safe, caution, danger. But the launcher is a must" |
| 3 | Base | **cleanyourtv** (MIT, Gradle, Java/View) | Owner's pick; gives `ClockDream`, `WallpaperRotation`, `InputKeyService` |
| 4 | Owner control | **Full settings** — mother is comfortable, owner will teach her | Owner chose the least restrictive option |
| 5 | Wallpaper + screensaver | **Both**: our launcher rotates the Home wallpaper; **keep Google's ambient screensaver** (`com.google.android.apps.tv.dreamx`) | Only one screensaver can be active; owner kept Google's ambient |
| 6 | Cultural extras | **Strip** — Diwali `DiyaDrawable`, `MarigoldDrawable`, `PetalShowerView`, `Shamsi` (Persian calendar), `RaceWeekend` | Not relevant to an Indonesian household |
| 7 | Visual language | **Liquid Glass**, implemented as **pre-computed CPU glass**, no library | See finding below — no library works on API 30 |
| 8 | Install procedure | **Safe path**: install as a normal app → launch manually → verify → switch HOME → reboot-test | It is his mother's daily TV |
| 9 | Android automation | **ARTEMIS installed** as MCP server, `--type adb` | Owner requested; verified 13 tools |

## The Liquid Glass finding (decisive, evidence-backed)

[O] Ground truth from `platforms/android-34/data/api-versions.xml`:

```
<class name="android.graphics.RuntimeShader" since="33">   ← AGSL shaders
<class name="android.graphics.RenderEffect"   since="31">   ← GPU blur
```

The TV is **API 30 (Android 11)**. Therefore:

- ❌ AGSL refraction is unreachable (needs 33)
- ❌ `RenderEffect` blur is unreachable (needs 31)
- ❌ `Window.setBackgroundBlurRadius` is unreachable (needs 31)
- ✅ Only translucent fills, gradients, rim strokes, and **static pre-blurred bitmaps**

Library audit — none usable:

| Repo | Stars | License | Verdict |
|---|---|---|---|
| `QmDeve/AndroidLiquidGlassView` | 331 | MIT | README: "On devices below **Android 13**, the view will maintain a transparent background and **will not render any effects**" → draws nothing on our TV |
| `Kyant0/AndroidLiquidGlass` | 4,237 | Apache-2.0 | Compose Multiplatform → would force a rewrite of cleanyourtv's Java/View base |
| `skydoves/Cloudy` | 1,286 | — | Compose only |
| `Mortd3kay/liquid-glass-android` | 186 | — | AGSL shaders, API 33+ |
| `lesnolie/Tigris` | 187 | MIT | **TV launcher with this exact problem already solved** — see below |

**Adopted technique**, validated by `lesnolie/Tigris`, whose README states
(translated from Chinese): *"The glass blur, edge refraction and coloured
highlights are **pre-computed on the CPU for the current background** (Android 12
has no runtime shaders), so scrolling costs no extra GPU."*

Ours: blur the wallpaper **once per rotation** — downsample → stack-blur →
upscale, off the render path — then composite glass panels with translucent fill,
rim gradient and a specular top-edge stroke. **Zero per-frame GPU cost.**

Rationale: a per-frame refraction shader on a **Mali-G31** [O] would deliver
beautiful glass and reproduce the exact lag the project exists to fix.

## Hardware facts that shaped the above

[O] GPU: **ARM Mali-G31**, OpenGL ES 3.2 (weak, entry-level Bifrost)
[O] RAM: 2,097,152 kB total, ~100 MB free, **516,780 kB swap in use**
[O] ABI: `armeabi-v7a` only — no arm64
[O] Display: 1920×1080 @ 320 dpi

## Performance ledger (why the launcher alone is not the fix)

[O] Memory reclaimable by change:

| Target | RSS | Action | Reclaims |
|---|---|---|---|
| `launcherx` + `:coreservices` | ~121 MB | replace with ours (~12 MB) | ~110 MB |
| TCL bloat: `bi`, `messagebox`, `usercenter`, `overseasappshow`, `guard`, `tclhome_passive` | ~212 MB | disable | most of it |
| `tungsten.setupwraith` | 29.5 MB | disable (setup complete) | 29 MB |
| `tv.dreamx:smarthome` | 33 MB | **keep** — this is the screensaver the owner wants | 0 |

[O] Lag smoking gun from `dumpsys usagestats` (under 3 min of idle):
`com.tcl.bi/BiReportService` START/STOP at 20:31:18, 20:33:50, 20:33:56,
20:33:58; plus `tcl.useragreement/CheckUpdateService` and
`tcl.usercenter/BootCompletedService` firing notifications. TCL telemetry wakes a
foreground service roughly every 30 s on a box that is already swapping.

[O] Crash buffer was **empty** — "crashing" is likely ANR / low-memory kills,
not a native fault. Not yet proven.

## What the mother actually uses [O]

`ACTIVITY_RESUMED` last 24h: YouTube ×12, Settings ×6. Task stack also holds
Netflix (`com.netflix.ninja`, running `visible=true`) and Live TV (`com.tcl.tv`).

Default dock assumption: **YouTube, Netflix, Live TV + 4 HDMI inputs.**
Owner chose full settings, so she can rearrange.

## TV input inventory [O] — what the switcher must handle

| Type | Count | Service |
|---|---|---|
| HDMI | 4 | `com.tcl.tvinput/.passthroughinput.TvPassThroughService` |
| Tuner (DTV / Live TV) | 2 | `com.tcl.tvinput/.TDTVInputService` |
| Composite | 2 | passthrough |
| VGA / SCART | 1 each | — |
| IP channels | — | `com.tcl.channelplus/.iptv.service.InputService` |

## ARTEMIS (installed 2026-10-21)

[O] `google/artemis` — Apache-2.0, 13.4k★, Python, MCP server. Not a skill.
Installed at `C:/Users/ryuen/Tools/artemis`, venv 888 MB, Python 3.12.

Config: `mcp_servers.artemis` = command `.venv/Scripts/artemis.exe`,
args `["mcp","--type","adb","--transport","stdio"]`, enabled.

[O] `hermes mcp test artemis` → **connected 4484 ms, 13 tools discovered.**

TV-useful: `press_key` (D-pad), `get_ui_hierarchy`, `launch_app`, `stop_app`,
`back`, `open_link`, `take_screenshot`, `erase_one_char`.
Touch-only / useless on TV: `tap`, `long_press_on`, `swipe`,
`focus_and_input_text`, `focus_and_clear_text`.

Tools surface as `mcp__artemis__*` after `/reload-mcp` or a new session.

Honest note: its `mcp_server/rules.md` ("Mobile Testing Mindset") contains no
TV, D-pad, keyevent or leanback content — it is phone test-automation
philosophy. The value is the adb actuator layer, not the mindset file.

## Open risks

1. **Gradle build unproven here** — cleanyourtv needs Gradle + AndroidX from
   Maven. JDK 21 and SDK 34/35 are present; Gradle is not installed. Must be
   proven with a build spike before any design work.
2. **Home key on AR09 unverified** — the AP08 report (different unit, Android 9)
   says the Home key worked with a replacement launcher. Our unit is AR09 /
   Android 11 / Google TV. Not yet tested.
3. **Launcher alone won't fix lag** — see the performance ledger.
4. **cleanyourtv is heavier than tv-detox** — mitigated by its R8
   `minifyEnabled` + `shrinkResources` release build.

## Deferred (explicitly)

- **Debloat inventory**, triaged safe / caution / danger — owner asked for this
  "later". Must classify every one of the 138 installed packages, with TCL
  services called out, and record original enable-state for rollback.
- Exact theme implementation of the CPU-glass technique.
- Whether to keep `LauncherSettingsActivity` / `QuickSettingsActivity` as-is.

## Verification (completed 2026-10-21)

**Gradle build — PASSED.** `./gradlew.bat assembleRelease` → `BUILD SUCCESSFUL in
1m 7s`, 44 tasks. Gradle 8.9 + AGP 8.5.2 running on Temurin JDK 21, SDK
`F:/Android Emulator/sdk`. Decision 3 validated; no need to reopen.

[O] Artifact: `app-release.apk` — **438,855 B (432 KB)**, package
`com.gathin.tvhome`, versionName 2.5, minSdk 26, targetSdk 34, **3 permissions**.
R8 `minifyEnabled` + `shrinkResources` cut it hard; my "heavier base" concern does
not survive the measurement.

**Install as normal app — PASSED.** `adb install -r` → `Success`. HOME handler
verified **unchanged** afterwards:
`com.google.android.apps.tv.launcherx/.home.HomeActivity`. Safe path held.

**Launch + render — PASSED.** Woke the TV, launched
`com.gathin.tvhome/.MainActivity`, screenshot captured. Renders correctly:

- "GOOD EVENING" / **20:59** / "WEDNESDAY 21 OCTOBER"
- Top-right pills: **Inputs**, **Ethernet**, **Settings**
- Dock: **Netflix** (focused, white glow ring), **YouTube**, **BrowseHere**,
  **Gallery**; a second row peeks from the bottom edge
- No errors, no missing icons, no misalignment
- Screenshot: `shots/tvhome-02.png`

[O] Side finding: the idle screensaver is
`com.google.android.apps.tv.dreamx/android.service.dreams.DreamActivity` — this
**confirms** `dreamx` is Google's ambient screensaver (decision 5), and it takes
the screen aggressively when idle. Any launch must wake the device first.

### Memory: measured on the same metric (PSS)

| Process | TOTAL PSS | TOTAL RSS | SWAP PSS |
|---|---|---|---|
| `com.gathin.tvhome` (ours) | **44,251 KB** | 125,460 KB | **208 KB** |
| `com.google.android.apps.tv.launcherx` | **87,133 KB** | 110,752 KB | **28,176 KB** |

**Correction to the earlier ledger.** I had estimated ~110 MB by comparing
launcherx's *RSS* (86.9 MB + 34.3 MB coreservices) against tv-detox's claimed
12 MB. Measured properly:

- Main-process saving: **~43 MB PSS** (87 MB → 44 MB)
- Plus `launcherx:coreservices` (~34 MB RSS, a separate process) is eliminated
  entirely once the package is disabled → **~76 MB PSS total**
- Plus launcherx was carrying **28 MB of swapped-out pages**; ours carries 208 KB.
  That relieves real pressure on a box that had 504 MB swapped.

So the win is real but smaller than first stated: **~76 MB, not ~110 MB**. Our
launcher is 44 MB PSS, not 12 MB — the 12 MB figure belonged to a different app.
The remaining gap must still come from the debloat list.

### Input switcher — RESOLVED (Live TV) / device-limited (HDMI 4)

**Two separate causes were found. One was ours to fix; one is not.**

#### 1. Live TV — FIXED

Root cause: `res/values/config.xml` ships
`live_tv_package = com.mediatek.wwtv.tvcenter` — **MediaTek's** TV Center. This TV
is **Realtek** (RTD2851M), so the package does not exist and `liveTvIntent()`
returned null, silently skipping the row (line 2371 guards on
`liveTv != null && tunerId != null`).

The tuner itself was fine all along: `com.tcl.tvinput/.TDTVInputService` is a
`FLAG_SYSTEM` app at `/product/app/TIF_TvInput/`, so the tuner-detection branch at
line 2309 passed; only the launch intent failed.

Fix applied (2 lines in `config.xml`):

```xml
<string-array name="hidden_apps">
    <item>com.tcl.tv</item>          <!-- was com.mediatek.wwtv.tvcenter -->
    ...
<string name="live_tv_package" translatable="false">com.tcl.tv</string>
```

`com.tcl.tv` advertises `LEANBACK_LAUNCHER` (10 hits in its manifest) [O], so it
resolves. It is also added to `hidden_apps` so it does not also appear as a
duplicate tile.

Rebuilt (9 s), reinstalled, verified on the TV:

- [O] Menu now reads: **HDMI 1** (Connected) · HDMI 2 · HDMI 3 · ── · **AV** · ── · **Live TV**
- [O] Selecting Live TV → `com.tcl.tv/.TVActivity` becomes `mResumedActivity` **and**
  `mFocusedApp`. The row works, not just renders.
- Screenshot: `shots/tvhome-05-inputs-fixed.png`

#### 2. HDMI 4 — firmware limitation, NOT fixable via the standard API

[O] Hardware exists: `TvInputHardwareInfo{id=1413745664, type=9, hdmi_port=4}`.
[O] But it has **no `TvInputInfo`**: `1413745664` appears 2× in `dumpsys tv_input`,
both times only as hardware/connection. Compare HDMI 1 (`1413744128`), which
appears 5× and includes its `TvInputInfo`.

TCL's `TIF_TvInput` registered passthrough inputs for HDMI ports **1, 2 and 3
only**. The launcher lists everything registered — there is nothing to list for
port 4. The stock Google TV launcher reads the same `TvInputManager` API and
therefore cannot offer it either.

Possible (unverified) workaround: a TCL vendor intent. `MainActivity` already
knows `com.tcl.settings.SHOW_WINDOW`. Whether it accepts an HDMI-4 argument is
unknown and would need its own investigation. Not attempted.

### Startup note

The `dreamx` screensaver takes the screen when idle, so every launch sequence must
send `KEYCODE_WAKEUP` first or the `am start` is covered by the dream.


## CUTOVER — DONE (2026-10-21)

The TV now boots into `com.gathin.tvhome`. Verified across a reboot **and** a
reinstall.

### What did NOT work, and why

1. **`cmd package set-home-activity com.gathin.tvhome/.MainActivity`** →
   prints `Success`, and changes nothing. HOME still resolved to
   `com.google.android.apps.tv.launcherx` immediately afterwards.
2. **`android:priority="3"` on the HOME intent-filter** → does not work either.
   Verified properly rather than assumed: the pulled-back installed APK contained
   `priority(0x0101001c)=3`, yet `cmd package query-activities` still reported
   `priority=0` for our activity after a reboot. **This build ignores
   `android:priority` for HOME resolution.** The change was reverted.

### What worked

```bash
pm disable-user --user 0 com.google.android.apps.tv.launcherx
```

With the stock launcher parked, our `priority=0` beats `FallbackHome`'s
`-1000` and becomes the only live HOME. This is why cleanyourtv's own install
script offers to turn the stock home screen off — the framework will not hand
HOME over otherwise.

### Rollback

`launcherx` is **disabled, never uninstalled** (`installed=true enabled=3`), so:

```bash
pm enable com.google.android.apps.tv.launcherx
# Google TV comes back without its notification access unless it is re-granted:
cmd notification allow_listener \
  com.google.android.apps.tv.launcherx/.coreservices.notificationlistener.TvNotificationListenerService
```

That second line is not optional — it is the workaround `tv-detox`'s `undo.sh`
documents as its issue #16.

### Measured result

| Metric | Before project | After Tier 1 | **After cutover** |
|---|---|---|---|
| Swap in use | 504 MB | 228 MB | **56 MB** |
| `MemAvailable` | 315 MB | 499 MB | **505 MB** |
| `launcherx` processes | 2 (`322 MB` RES) | 2 | **0** |
| Our launcher PSS | — | 44 MB | **29 MB** |
| Disabled packages | 5 | 25 | **26** |

Swap in use is down **89%** from where this started, and the stock launcher is
gone from `ps` entirely.

## Next step

1. Verify interactions on the real TV: D-pad focus movement, **Inputs** menu
   (must list Live TV + HDMI 1–4), Settings pill, and the app library.
2. Only then: switch HOME via `cmd package set-home-activity`, reboot, and
   confirm the physical Home key reaches our launcher on AR09 (open risk 2).
3. Then produce the **debloat inventory** (safe / caution / danger) — it is now
   load-bearing for the performance goal, not just hygiene.

