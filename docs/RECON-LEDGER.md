# TCL Smart TV Pro — Recon Ledger

Verified against the live device on 2026-10-21. Every line below is an observation
from `adb` against 192.168.31.35:5555, not an assumption. Tag: [O]=observed.

## Connection

- [O] `adb connect 192.168.31.35:5555` → `unauthorized` on first attempt, then
  `device` after the on-screen RSA prompt was accepted. Host key:
  `C:\Users\ryuen\.android\adbkey.pub` (created 2024-07-19).
- [O] adb client: Android Debug Bridge 1.0.41 / platform 37.0.1
  (`F:/Android Emulator/sdk/platform-tools/adb.exe`).

## Device identity

| Property | Value |
|---|---|
| ro.product.manufacturer | TCL |
| ro.product.model | Smart TV Pro |
| ro.product.device | BeyondTV4 |
| ro.product.name | G03_4K_GB |
| ro.product.board | RTD2851M |
| ro.hardware / ro.board.platform | rtd288o (Realtek) |
| ro.build.version.release / sdk | 11 / 30 |
| ro.build.version.incremental | AR09 |
| ro.build.fingerprint | TCL/G03_4K_GB/BeyondTV4:11/RP1A.200622.001/AR09:user/release-keys |
| ro.build.date | Wed May  8 12:40:09 CST 2024 |
| ro.build.type / tags | user / release-keys |
| ro.build.characteristics | nosdcard,tv |
| ro.product.cpu.abi | **armeabi-v7a** (abilist: armeabi-v7a, armeabi) |
| wm size / density | 1920x1080 / 320 (xhdpi) |

### 32-bit caveat
`ro.product.cpu.abilist` has **no arm64-v8a**. Any NDK/native code must ship
`armeabi-v7a`. A pure Java/Kotlin launcher has **no ABI constraint at all** —
this only bites if we link native libs.

## Root / modification posture

- [O] `id` → `uid=2000(shell) ... context=u:r:shell:s0`
- [O] `ro.secure=1`, `ro.debuggable=0`, `ro.build.type=user`, `release-keys`
- [O] `ro.boot.verifiedbootstate=green` (locked bootloader, verified boot intact)
- [O] no `su` anywhere (`which su` empty, `/system/{bin,xbin}/su` absent)
- [O] mounts: `/product` **ro**, `/vendor` **ro**, `/data` **rw**
- [O] `/data` free: 3.2G of 10G

**Conclusion:** effectively unrootable without a Realtek BSP exploit. `ro.*` prop
writes, `build.prop` edits, `/product` or `/vendor` modification are all out.
User-facing settings via `settings put` are in.

## Launcher surface (the part that decides the project)

Default HOME handler [O]:

```
priority=2 ... isDefault=true
com.google.android.apps.tv.launcherx/com.google.android.apps.tv.launcherx.home.HomeActivity
```

Exactly **three** HOME-capable activities exist [O]:

1. `com.google.android.apps.tv.launcherx/.home.HomeActivity` — priority 2, default, enabled
2. `com.google.android.tungsten.setupwraith/.RecoveryActivity` — priority 1, **enabled=false**
3. `com.android.tv.settings/.system.FallbackHome` — **priority -1000** (the AOSP TV safety net)

### Why this is a good configuration
- [O] `settings get secure home_component` → **null** → no vendor pin; the system
  is resolving HOME by priority, not from a locked component.
- [O] `cmd package set-home-activity [--user USER_ID] TARGET-COMPONENT` **exists**
  on this build, plus `--activity-task-on-home` / `--activity-match-external`.
- [O] **No `com.tcl.*` package declares `android.intent.category.HOME`** — checked
  all 7 candidates, 0 hits each. The vendor does not install a competing HOME handler.
- [O] `FallbackHome` is present and exported → a recovery route if a custom
  launcher misbehaves.

### The two scare-words, resolved
- [O] `com.tcl.tv.tclhome_passive` (`/product/app/TCLHome_passive/`) — declares
  **LAUNCHER** only, plus `BootCompleteReceiver` and two content providers
  (`AppPassiveContentProvider`). It is a passive tile/content feed, **not** a HOME
  handler. HOME-category hits: 0.
- [O] `com.tcl.guard` (`/product/app/TGuard/`) — permission shield / privacy UI
  (`PermissionShieldActivity`, `SensitivePermissionActivity`). HOME hits: 0.
  Not a launcher watchdog.

## Stock launcher (RE reference)

Pulled [O]: `/data/app/~~Xjoe4-dd50hwDEKpkfWHWw==/.../base.apk` → 23,897,105 bytes
(23M), in 3.0s. Splits: `split_config.armeabi_v7a.apk` (197,256 B),
`split_config.en.apk`, `split_config.xhdpi.apk`.

From `aapt2 dump badging` [O]:
- package `com.google.android.apps.tv.launcherx`, versionName `1.0.994451607`
- `application-label:'Google TV'` — so the user-facing name is **Google TV**, not "TCL"
- targetSdkVersion **36**, compileSdk 37, minSdkVersion 29
- `uses-feature: android.software.leanback` (required)
- `uses-feature: com.google.android.feature.AMATI_EXPERIENCE`
- **57** uses-permission entries
- `seinfo=default:privapp`, uid 10018, `sharedLibraryFiles=[com.android.libraries.tv.tvsystem.jar]`

### Permission gap that constrains OUR launcher
LauncherX holds privileged permissions a third-party app cannot obtain [O]:
`MANAGE_USERS`, `INTERACT_ACROSS_USERS`, `DELETE_PACKAGES`, `FORCE_STOP_PACKAGES`,
`INSTALL_EXISTING_PACKAGES`, `WRITE_SECURE_SETTINGS`, `DUMP`, `READ_LOGS`,
`GET_ACCOUNTS_PRIVILEGED`, EPG data permissions.

**Design consequence:** our launcher can *launch* apps and *enumerate* them, but
cannot uninstall, force-stop, or write secure settings. Feature scope must be set
against that line, not against what Google TV appears to do.

## Installed third-party apps (user already sideloads)

[O] Plex, iflix, Xplore (file manager), Spotify TV, Vision+, Tencent QQLive,
Kodi, iQiyi, VLC.

[O] Also user-disabled preinstalls: `au.com.stan.and`, `com.amazon.amazonvideo.livingroom`,
`com.google.android.youtube.tvmusic`, `tv.wuaki.apptv`, `com.tcl.smartalexa`.

Confirms sideloading is already part of this user's workflow — installing our own
APK is not a new capability on this device.

## Verdict per goal

| Goal | Verdict | Basis |
|---|---|---|
| RE the TV / its launcher | Feasible, clean | adb pulls at 7.6 MB/s; REA JEB + Ghidra + local aapt2 all present |
| Tweak settings | Partial — user-facing yes, system-level no | locked bootloader, green verified boot, no su, /product + /vendor ro |
| Replace default launcher with our own | Feasible, unrooted path exists | set-home-activity present, home_component null, no vendor HOME handler, FallbackHome recovery |

## OPEN UNKNOWN — the one experiment that closes it

**Does the physical TCL remote's HOME key route through the system HOME intent,
or does the vendor intercept it and force-launch LauncherX?**

Known-good facts do not answer this. Everything above shows the *system* will
accept a third-party HOME component; nothing shows the *remote* respects it.
On several vendor TV builds the remote Home key is intercepted in a
proprietary input path and hard-launches the stock launcher, which would make a
custom launcher unreachable by the one button users actually press.

### The experiment (reversible)
1. Build a minimal ~30-line "Hello Home" activity declaring
   `MAIN` + `HOME` + `DEFAULT`, minSdk 21, targetSdk 30, **no native code**.
2. `adb install` it, then `cmd package set-home-activity <pkg>/.MainActivity`.
3. Press HOME on the remote. Observe whether our activity appears.
4. Reboot and press HOME again — tests whether a boot-time service resets it.
5. Restore: `cmd package set-home-activity com.google.android.apps.tv.launcherx/.home.HomeActivity`
   (or `com.android.tv.settings/.system.FallbackHome` if the stock one misbehaves).

This is a device mutation on a daily-driver TV, so it runs only on explicit approval.

## Not yet done
- Stock launcher resources/classes decompiled (manifest read only, via aapt2)
- No AVD created for launcher UI iteration
- HOME-key behaviour untested (above)
