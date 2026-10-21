# Debloat Inventory — TCL Smart TV Pro (AR09 / Android 11 / API 30)

Built from live `adb` evidence on 2026-10-21. Every classification below is either
**[O]** measured on this device or **[E]** external evidence (the cleanyourtv
`tcl-beyondtv-ap08` report, a sibling unit — Android TV 9, different build, so it
corroborates but does not prove).

## Ground rules

- **Nothing is uninstalled.** Only `pm disable-user`, which is reversible with `pm enable`.
- **Mechanism verified** [O] on `com.tcl.esticker`: `disable-user --user 0` →
  `new state: disabled-user`, `pm enable` → `new state: enabled`, as `uid=2000(shell)`.
  **No root required.**
- Disabling is per-user (`--user 0`). Package data is preserved.
- **Record the baseline first.** 5 packages were already disabled by the owner and
  must not be "restored" by any script:

```
au.com.stan.and
com.amazon.amazonvideo.livingroom
com.google.android.youtube.tvmusic
com.tcl.smartalexa
tv.wuaki.apptv
```

## Inventory

139 packages total: 129 system, 10 third-party. 28 carry a `LEANBACK_LAUNCHER`
activity, i.e. they appear as pressable tiles.

---

## TIER 1 — SAFE

Telemetry, promos, duplicates, or dead weight. None is a tile the owner uses;
none is a dependency of Live TV, the inputs, the remote, or DRM.

| Package | What it is | Evidence | Resident |
|---|---|---|---|
| `com.tcl.bi` (+ `.persistent`) | TCL analytics / telemetry | **[O]** fires `BiReportService` START/STOP every ~30 s; **[E]** AP08 disabled, stable after reboot | 43 MB |
| `com.tcl.usercenter` | TCL account centre | **[O]** boots `BootCompletedService` + notification | 52 MB |
| `com.tcl.messagebox` | TCL message/notification push | **[O]** resident; **[O]** raises notifications | 43 MB |
| `com.tcl.overseasappshow` | TCL app-promotion surface ("overseas app show") | **[O]** resident | 39 MB |
| `com.tcl.tv.tclhome_passive` | Passive TCL home promotion (tile feed) | **[O]** LAUNCHER category only, no HOME; **[E]** AP08 disabled | 25 MB |
| `com.tcl.esticker` | Retail/demo stickers | **[E]** AP08 disabled | — |
| `com.tcl.logkit` | `/system/app/Logkit` — logging | **[O]** path only | — |
| `com.tcl.useragreement` | EULA + update checker | **[O]** `CheckUpdateService` + notification at boot | — |
| `com.tcl.gamebar` | Game-bar overlay (no games here) | **[O]** tile, no usage | — |
| `com.tcl.hearaid` | Hearing-aid support | **[O]** tile, no usage | — |
| `com.tcl.ocean.instructions` | TCL "instructions" app | **[O]** tile, no usage | — |
| `com.tcl.android.webview` | TCL WebView fallback | **[O]** active provider is `com.google.android.webview` — this one is **not** in use | — |
| `com.google.android.feedback` | Google feedback reporter | **[E]** AP08 disabled | — |
| `com.google.android.tungsten.setupwraith` | Setup wizard — setup is long done | **[O]** resident, `enabled=false` for HOME; **[E]** AP08 kept enabled but it advertises no HOME here either | 23 MB |
| `com.android.printspooler` | Printing (no printer) | **[O]** no print usage | — |
| `com.android.camera2` | Camera app — device has no camera | **[O]** no camera hardware | — |
| `org.chromium.webview_shell` | WebView shell demo | **[O]** demo app | — |
| `com.android.htmlviewer` | Local HTML viewer | **[O]** trivial | — |
| `com.android.wallpaperbackup` | Wallpaper backup stub | **[O]** trivial | — |

**Expected recovery [O]:** ~225 MB resident from the six memory-heavy entries
(`bi.persistent` 43 + `usercenter` 52 + `messagebox` 43 + `overseasappshow` 39 +
`tclhome_passive` 25 + `setupwraith` 23).

---

## TIER 2 — CAUTION

Works, but something here is a real feature. Decide per household, one at a time,
and re-test after each.

| Package | What it is | Why caution | Resident |
|---|---|---|---|
| `com.google.android.katniss` | **Google Assistant** (voice search) | Disabling frees the most of anything here (~112 MB across `:search` + `:interactor`) but kills the remote's voice button and Assistant | 112 MB |
| `com.android.vending` | **Play Store** (with `:background` at 102 MB) | Needed to update/reinstall apps; disabling it is hard to undo without a working store | 102 MB |
| `com.tcl.browser` | "BrowseHere" browser — **appears in the dock** | A tile she may press | — |
| `com.tcl.gallery` | Gallery — **appears in the dock** | Same | — |
| `com.tcl.ui_mediaCenter` | TCL media player | Plays USB/local media | — |
| `com.tcl.dashboard` | TCL dashboard tile | Visible tile | — |
| `com.tcl.waterfall.overseas` | TCL content waterfall | Visible tile | — |
| `com.tcl.t_solo` | TCL "T_Solo" utility tile | Visible tile | — |
| `com.tcl.channelplus` | TCL Live/IP channels (`TCL_Live.apk`) | Registers a TV input; may be her second Live TV path | — |
| `com.tcl.guard` | Permission/privacy shield (`TGuard`) | Privacy guard she may rely on | 36 MB |
| `com.tcl.micmanager`, `com.tcl.assistant` | Mic + Assistant bridges | Break voice if she uses it | — |
| `com.tcl.MultiScreenInteraction_TV`, `com.tcl.miracast` | T-Cast / Miracast screen casting | She may cast from her phone | 23 MB |
| `com.tcl.inputmethod.international` | TCL keyboard | Needed if she ever types (search box) | 22 MB |
| `com.tcl.versionUpdateApp` | **Firmware updater** | **[E]** AP08 disabled it only at the owner's explicit request, not by default — a TV that never updates may drift | — |
| `com.tcl.xian.StartandroidService` | `DeviceAuthenCommon` — device authentication | Could affect DRM/auth in streaming apps; **unverified** | 52 MB |
| `com.tcl.factory.view` | Factory/service menu | Harmless to users, but service may want it | — |
| `com.google.android.play.games` | Play Games | Visible tile | — |
| `com.google.android.videos` | Play Movies & TV | Visible tile; **[E]** AP08 disabled its recommendations | — |
| `com.google.android.tv.remote.service` | Android TV remote (phone app) pairing | If anyone drives the TV from a phone | 21 MB |
| `com.google.android.marvin.talkback` | TalkBack accessibility | Only if accessibility is needed | — |
| `com.google.android.apps.mediashell` | Media session shell | Ties into playback surfaces | 40 MB |
| `com.android.messaging`, `com.android.providers.calendar` | Messages / calendar providers | Only if notifications use them | — |

---

## TIER 3 — DANGER / DO NOT TOUCH

Removing any of these breaks a core function, the remote, the inputs, or our own
recovery path.

| Package | Why |
|---|---|
| `com.tcl.tv` | **Live TV** — she uses it, and it is the target of our fixed Inputs row (`com.tcl.tv/.TVActivity`) |
| `com.tcl.tvinput` | **Every TV input** — HDMI 1–3, AV, and the DTV tuner. Disabling empties the Inputs menu |
| `com.tcl.settings` | TCL picture/sound/input settings |
| `com.tcl.tcl_bt_rcu_service` | **Bluetooth remote service** — `TCL_RC902V_M6` is a live input device [O] |
| `com.tcl.autopair` | Bluetooth pairing/auto-pair for the remote |
| `com.tcl.providers.config` | `/system/priv-app` config provider other TCL apps read |
| `com.android.tv.settings` | Contains **`FallbackHome`** — our last-resort recovery launcher |
| `com.android.systemui` | System UI |
| `com.android.providers.settings` | Settings database |
| `com.android.providers.tv` | TV channel/EPG database — Live TV needs it |
| `com.google.android.gms`, `com.google.android.gsf` | Play Services — Netflix and YouTube depend on it |
| `com.google.android.permissioncontroller` | Permission enforcement |
| `com.google.android.webview` | **The** active WebView provider [O] |
| `com.google.android.apps.tv.dreamx` | **The screensaver the owner chose to keep** (decision 5) |
| `com.android.bluetooth` | Bluetooth stack |
| `com.android.vending` | Listed again here: disabling it is hard to reverse without a store |
| `com.android.shell`, `android`, `com.android.providers.media*`, `com.android.externalstorage`, `com.android.networkstack*` | Framework / storage / network |

---

## Combined expectation

| Change | Metric | Amount |
|---|---|---|
| Replace `launcherx` + `:coreservices` with ours | **PSS** (measured) | **~76 MB** |
| Tier 1 SAFE disables | resident (RES) | **~225 MB** |
| Tier 2 if voice is unused | resident (RES) | ~112 MB more |
| Tier 2 if Play Store background is controlled | resident (RES) | ~102 MB more |

RES and PSS are **not interchangeable** — RES counts shared pages once per
process and reads high. Use RES to rank, PSS to claim. The honest combined
figure needs a reboot + re-measure, not a sum of columns.

Also note: during measurement the device was serving **scrcpy** (`app_process`
74 MB + 48 MB). That is our instrumentation, not the TV's baseline, and must be
disconnected before any before/after comparison is trusted.

## APPLIED — Tier 1 (2026-10-21)

18 packages disabled, `com.tcl.useragreement` deliberately **held back** (it runs
`CheckUpdateService`, so it was left alone rather than assumed harmless — the
firmware updater `com.tcl.versionUpdateApp` was never in Tier 1 and remains
enabled).

Applied set:

```
com.tcl.bi                        com.tcl.usercenter
com.tcl.messagebox                com.tcl.overseasappshow
com.tcl.tv.tclhome_passive        com.tcl.esticker
com.tcl.logkit                    com.tcl.gamebar
com.tcl.hearaid                   com.tcl.ocean.instructions
com.tcl.android.webview           com.google.android.feedback
com.google.android.tungsten.setupwraith
com.android.printspooler          com.android.camera2
org.chromium.webview_shell        com.android.htmlviewer
com.android.wallpaperbackup
```

### Proof that nothing was uninstalled

[O] After applying, all 18 report `installed=true` and `enabled=3`
(`COMPONENT_ENABLED_STATE_DISABLED_USER`) — present on disk, disabled for the user.
`pm list packages` still returns **139** packages, unchanged from before.
Disabled count went 5 → 23 and **persisted across a reboot**.

### Measured result — rebooted, scrcpy disconnected

| Metric | Baseline | After Tier 1 | Delta |
|---|---|---|---|
| `MemFree` | 102,532 kB | **149,520 kB** | +46,988 kB |
| `MemAvailable` | 315,100 kB | **593,436 kB** | **+278,336 kB (+272 MB)** |
| Swap in use | 516,780 kB | **233,216 kB** | **−283,564 kB (−277 MB)** |
| Installed packages | 139 | 139 | 0 (nothing removed) |

**The swap number is the one that matters.** The TV was holding 504 MB of swapped
pages at rest; it now holds 228 MB. Those pages were being paged back in on every
app switch — that is the lag, and it is roughly halved.

Debloated processes no longer appear at all: `com.tcl.bi`, `usercenter`,
`messagebox`, `overseasappshow`, `tclhome_passive` are gone from `ps` after boot.

### Functional smoke test after reboot

[O] All launched successfully to their real activities:

- YouTube → `com.google.android.youtube.tv/...MainActivity`
- Netflix → `com.netflix.ninja/.MainActivity` (confirms `gms`/DRM intact)
- Live TV → `com.tcl.tv/.TVActivity`
- HOME → back to `launcherx`

**Still to check by hand (needs the physical remote):** every remote button,
HDMI 1–3 picture, audio, picture/sound settings, phone casting.

## Apply procedure

```bash
ADB="F:/Android Emulator/sdk/platform-tools/adb.exe"; D="-s <TV_IP>:5555"

# 1. Snapshot the baseline first — this IS the rollback
"$ADB" $D shell 'pm list packages -d' > baseline-disabled.txt

# 2. Apply one tier at a time, never a mixed batch
for p in com.tcl.bi com.tcl.usercenter com.tcl.messagebox \
         com.tcl.overseasappshow com.tcl.tv.tclhome_passive com.tcl.esticker; do
  "$ADB" $D shell "pm disable-user --user 0 $p"
done

# 3. Reboot, then re-measure with scrcpy disconnected
"$ADB" $D shell reboot

# 4. Verify each thing she uses: Live TV, HDMI 1-3, YouTube, Netflix, Settings,
#    audio, picture, and the remote's every button.

# Rollback, any single package
"$ADB" $D shell "pm enable <package>"
```

## Verification checklist after each tier

- [ ] Physical remote: every button (Home, Input/Source, Settings, volume, voice, app shortcuts)
- [ ] Live TV opens and tunes
- [ ] HDMI 1, 2, 3 switch and show picture
- [ ] YouTube plays with **sound**
- [ ] Netflix launches and plays (checks DRM/`gms`)
- [ ] Settings → picture/sound still opens
- [ ] Phone casting still discovers the TV
- [ ] Reboot, then confirm nothing new appears in `pm list packages -d`
