# Per-App Audio Mixer — Design Spec

Date: 2026-09-23
Status: Approved design, ready for implementation planning

## Goal

Add a per-app volume mixer to Perde as a new notch tab. The user can set an
individual output volume for each app producing audio, mute it, and route it to
a different output device — with no audio driver, using public Core Audio
process taps (macOS 14.4+; Perde targets macOS 15+).

Feasibility was proven with a throwaway spike: tapping Spotify, muting its
direct output, and re-rendering it through a private aggregate device at 0.25
gain audibly lowered only Spotify while Chrome/YouTube kept playing at full.

## Scope

### In scope (MVP)
- Per-app volume slider (0–100%).
- Per-app mute / unmute.
- Per-app output-device routing (send an app to a chosen output).
- Per-row reset (return to 100% / unmuted / default output).
- App list source is a Settings preference (precise definitions below):
  - **"only playing"** — processes with `kAudioProcessPropertyIsRunningOutput == true`.
  - **"all"** — every process in the Core Audio process object list (apps
    registered with the audio HAL), whether or not currently outputting.
- Persistence: remember settings per app by bundle ID; re-apply when the app
  reappears.

### Out of scope (explicitly deferred)
- Volume boost above 100%.
- Favorites / pinning / reordering.
- Master volume (the system already provides this).

## Core principle

An app is only intercepted when the user diverts it from default — volume < 100%,
muted, or routed to a non-default output. Apps at 100% + unmuted + default output
are never tapped and play normally. This keeps CPU low and limits real-time audio
processing to apps the user actually adjusts.

## Components

Each unit has one responsibility, communicates through a narrow interface, and is
testable in isolation. The engine is pure Core Audio and knows nothing about the UI.

### 1. `AudioProcessMonitor`
- Reads the Core Audio process object list
  (`kAudioHardwarePropertyProcessObjectList`).
- For each process: bundle ID, PID, name/icon (resolved from the running
  application), and whether it is currently producing output
  (`kAudioProcessPropertyIsRunningOutput`).
- **Groups process objects by owning app** (bundle ID / responsible PID) so a
  single row (e.g. "Chrome") covers all of an app's audio-producing helper
  processes. Audio frequently originates from helper processes
  (`com.google.Chrome.helper`), so grouping is required, not optional.
- Publishes the current app list and refreshes on change
  (property listeners on the process list).

### 2. `AppAudioController` (engine)
Sets up / tears down the interception chain for a single app. Inputs: the app's
process objects, gain (0–1), muted, target output device UID (nil = default).

Chain (proven in the spike):
1. **Process tap** — `CATapDescription(stereoMixdownOfProcesses:)` over the app's
   process objects, `muteBehavior = .mutedWhenTapped`, `isPrivate = true`. The
   app's direct output is silenced; we receive its audio.
2. **Private aggregate device** — main sub-device = the target output device
   (default or the user's choice; this is where routing is expressed via
   `kAudioAggregateDeviceMainSubDeviceKey`) plus the tap in the tap list,
   `kAudioAggregateDeviceTapAutoStartKey = true`.
3. **Gain IOProc** — multiplies tap buffers by `volume` and writes them to the
   target output. `muted` ⇒ gain 0. Sample-rate / channel differences between
   tap and output are matched (drift compensation on the tap sub-device;
   channel mapping in the IOProc).

Lifecycle:
- Built when the app first needs active control.
- Rebuilt when the target output device or the app's process set changes
  (`AudioObjectAddPropertyListener`).
- Torn down when the app returns to default (100% + unmuted + default output),
  when the app quits, or when its audio stops. Teardown returns the app to normal.

Multiple adjusted apps ⇒ one independent tap + aggregate + IOProc each.

### 3. `AudioMixerStore` (`ObservableObject`)
The layer the UI binds to.
- Holds `[bundleID: AppAudioSetting]` where
  `AppAudioSetting = { volume: Double, muted: Bool, outputDeviceUID: String? }`.
- Merges the live monitor list with saved preferences into published rows.
- On a user change, updates the setting, drives the matching
  `AppAudioController`, and persists.
- Persists settings as JSON in `UserDefaults`, keyed by bundle ID. When an app
  appears with a saved non-default setting, it is applied automatically.
- Reset removes the setting, tears down the controller, and deletes the
  persisted entry.

### 4. `MixerView` (SwiftUI)
The new 5th notch tab. A scrollable list of app rows; empty state
"Ses çalan uygulama yok" when the "only playing" source is active and nothing
is playing. Each row:
- app icon + name
- output-device menu (top-right): "Varsayılan" + system output devices
- volume slider + % label + reset (↺) + mute (🔊 / 🔇)

Styling follows Perde's existing view patterns and brand tokens (`Theme`) — no
third-party component library; this is an app-specific row.

### 5. Integration
- `NotchTab.mixer` case; tab-bar icon `slider.vertical.3`.
- `NotchGeometry` card size for `.mixer` (tall, scrollable, like clipboard).
- `SettingsStore` / `SettingsView`: enable/disable "Ses Mikseri" tab toggle
  (like the other tabs) + a new "Mikser listesi" preference
  (only-playing vs all apps).
- Verify 5 icons fit the tab bar at the notch width.

## Data flow

```
AudioProcessMonitor ──process list──► AudioMixerStore ◄──merge── UserDefaults (prefs)
                                            │ published rows
                                            ▼
                                        MixerView
                                            │ user: slider / mute / output
                                            ▼
                                        AudioMixerStore ──► AppAudioController (build/update/teardown)
                                            │
                                            └──► persist setting to UserDefaults
```

## Error handling & edge cases
- **Audio-capture permission denied** → show "Ses izni gerekli" with a pointer to
  Settings instead of rows; disable controls. Add the usage-description key to
  `Info.plist`. (The spike triggered no prompt, but a clean install may.)
- **Tap / aggregate creation fails** → revert the row to 100%, show a subtle
  error, log.
- **App quits while tapped** → tear down.
- **Selected output device removed** → fall back to default.
- **Multiple helper processes** → handled by app-level grouping in the monitor.

## Known limitations (accepted)
- **Latency / A-V sync:** tapping and re-rendering adds slight delay. Fine for
  music; adjusting a **video** app's volume (e.g. YouTube) may cause minor
  lip-sync drift. We will observe this and, if needed, warn or limit for video
  apps.
- **Unsigned build:** ad-hoc signing sufficed in the spike; notarization is a
  separate future concern.

## Testing
- **Unit tests** (added to the existing suite): gain computation; the
  build/teardown threshold (is this setting default?); format / channel mapping;
  preference merge logic — all as pure functions behind a thin Core Audio layer.
- **Manual checklist:** Spotify 50% + Chrome 100% → only Spotify drops; mute;
  change output device; quit/relaunch app → setting remembered.
