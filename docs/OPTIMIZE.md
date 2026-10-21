# Further optimisation — after Tier 1

Measured on 2026-10-21 **after** the Tier 1 debloat and a reboot. Where a RES
figure appears it is a *ranking* signal only: RES counts shared pages once per
process and reads roughly 2–3× high. PSS is the figure to quote as a saving.

State at time of measurement: `MemAvailable` 470 MB, swap in use 367 MB,
`ro.config.low_ram=false`, animations already at `0.5`.

Two mechanisms were **test-verified working** before being listed here:
`settings put global cached_apps_freezer enabled` (readback `enabled`) and
`am set-standby-bucket <pkg> restricted|active` (returned 40, then 10).

---

## A. Biggest single win — finish the launcher swap

| Process | RES now |
|---|---|
| `com.google.android.apps.tv.launcherx` | 213 MB |
| `com.google.android.apps.tv.launcherx:coreservices` | 109 MB |
| **total stock** | **322 MB** |
| ours (`com.gathin.tvhome`) | 128 MB |

Measured on **PSS**, the honest figure is **87 MB → 44 MB** for the main process,
plus the whole `:coreservices` process disappears: **~76 MB PSS**.

Beyond memory, replacing it removes Google TV's sponsored rows and content feeds —
which is the point of the project. Nothing else on this list is close.

**Risk:** low, already verified rendering and D-pad. Requires the reboot +
physical-Home-key test.

---

## B. Debloat Tier 2 — ranked by recoverable memory

| # | Target | RES now | Mechanism | Real cost |
|---|---|---|---|---|
| 1 | `com.google.android.katniss` (`:search` + `:interactor`) | **187 MB** | `pm disable-user` | **Kills the remote's voice button.** It is the registered `voice_interaction_service` (`KatnissVoiceInteractionService`) — not merely an app |
| 2 | `com.tcl.MultiScreenInteraction_TV` (+ `com.tcl.miracast`) | 104 MB | disable | Phone screen-casting stops working |
| 3 | **Second keyboard** — `com.tcl.inputmethod.international` | 79 MB | disable one | TCL `T_IME` is the **default**; Gboard is installed and resident (100 MB). Keep one: disabling TCL's saves ~79 MB, disabling Gboard's saves ~100 MB |
| 4 | `com.android.vending:background` | 102 MB* | disable `com.android.vending` | Play Store gone — cannot update or reinstall apps. *Measured pre-Tier-1 |
| 5 | `com.tcl.guard` (TGuard) | 88 MB | disable | Permission/privacy shield UI; has its own tile |
| 6 | `com.tcl.xian.StartandroidService` (`DeviceAuthenCommon`) | 84 MB | disable | **Unverified** — device authentication may gate DRM in streaming apps. Must test Netflix after |
| 7 | `com.google.android.apps.mediashell` | 87 MB | disable | Google TV media-session shell; may affect playback controls |
| 8 | `com.google.android.tv.remote.service` | — | disable | Phone-as-remote pairing |
| 9 | `com.google.android.play.games` | — | disable | Play Games tile |
| 10 | `com.google.android.videos` | — | disable | Play Movies tile |
| 11 | `com.tcl.versionUpdateApp` | — | disable | **Firmware updater.** Leave enabled unless a frozen firmware is wanted |
| 12 | `com.tcl.useragreement` | — | disable | EULA + `CheckUpdateService` — held back in Tier 1 for this reason |

Rough ceiling if 1–5 are all taken: **~560 MB RES / maybe ~150 MB PSS**. Item 1
alone is worth more than all the trivia combined — and costs the voice button.

---

## C. System tuning — no feature loss

| Change | Command | Why |
|---|---|---|
| **Enable cached-apps freezer** ✅ already set, needs reboot | `settings put global cached_apps_freezer enabled` | Android 11 feature, **off on this TV** (`use_freezer=false`). Freezes cached apps instead of letting them burn CPU and pages — exactly the workload that makes a 2 GB set stutter |
| Restrict unused third-party apps to the **restricted** standby bucket | `am set-standby-bucket <pkg> restricted` | Verified working (40 → 10). Stops background wakeups for apps she never opens |
| Animations `0.5` → `0` | `settings put global window_animation_scale 0` (×3) | Already halved; going to zero is marginal but free |
| Restrict the 8 unused streaming/media apps | see D | Removes clutter she scrolls past |

Apps never opened in the 24 h usage sample, all safe standby-bucket candidates:
`com.plexapp.android`, `org.xbmc.kodi`, `org.videolan.vlc`,
`com.spotify.tv.android`, `com.iqiyi.i18n.tv`, `com.tencent.qqlivei18n`,
`iflix.play`, `com.lonelycatgames.Xplore`.
Disabling rather than restricting is stronger — but it removes tiles, so it is
her call, not an optimisation default.

---

## D. Freeing disk (not RAM)

`/data` was 6.7 GB used of 10 GB. The launcher's own cache and the TV provider's
EPG database are the two large, safe-looking areas — but clearing `providers.tv`
loses the channel list, so it is **not** a casual cleanup. Clear app caches only:

```bash
adb shell pm trim-caches 2000M
```

---

## Recommended order

1. **Enable the freezer + reboot** — largest effect for zero feature loss.
2. **Finish the launcher** — ~76 MB PSS and removes the ads.
3. **Pick one keyboard** — ~79–100 MB, one decision, no real loss.
4. **Casting** (104 MB) if nobody casts from a phone.
5. **Assistant** (187 MB) only if the voice button is genuinely unused — it is
   the single biggest remaining win and the only one with a visible cost.

## What not to bother with

- `system_server` (178 MB), `gms` (160 MB), `systemui` (115 MB),
  `providers.media.module` (83 MB), `ext.services` (82 MB), `zygote` (79 MB),
  `bluetooth` (79 MB) — framework. Disabling breaks the TV.
- `providers.tv` (111 MB) — holds the Live TV channel/EPG data.
- `tcl_system_server` (79 MB) — vendor system server.
- `ro.config.low_ram` — a `ro.*` build property. Needs root, which this TV does
  not have. Leave it.
