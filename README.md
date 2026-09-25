# Note Reader

A small, friendly iOS app for learning to read notes on the treble and bass staff.
Czech note names (`c d e f g a h`, `h` instead of `b`, middle C = `c1`), three game modes
(Practice, Sprint, Streak), smart repetition of the notes that trip you up, per-note stats,
and a light-pink theme.

- Swift 5.9 / SwiftUI, iOS 16+, iPhone only, portrait, **no third-party dependencies**.
- The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`.
- Built **unsigned** on GitHub Actions (macOS runner) and sideloaded with a free Apple ID.
  No Mac needed on your side.

> **Zero-cost install (recommended):** the same app also exists as a **web app** in `web/`,
> published free on GitHub Pages. She opens the link in Safari and taps **Share → Add to Home Screen**.
> No cable, no Apple ID, no 7-day limit. See [Web app](#web-app-zero-cost-no-cable) below.
> The native iOS project remains for a future TestFlight release.

```
project.yml                 XcodeGen spec (bundle id, deployment target, signing)
NoteReader/
  NoteReaderApp.swift       App entry, shared state objects
  Models/                   Note (Czech names), Clef (staff table), RangePreset, Stats, AppSettings
  Engine/                   NotePicker (weighted + repetition), GameSession (modes, sprint timer)
  Audio/                    ToneSynth (AVAudioEngine synth), Haptics
  Views/                    Home, Game, StaffView (Canvas), AnswerLetters, PianoKeys, Settings, Stats, Results
  Assets.xcassets           AppIcon (1024 px single-size)
  Info.plist
web/                        Web app (PWA): index.html, app.js, styles.css, sw.js, manifest, icons
.github/workflows/build.yml CI: xcodegen → xcodebuild archive → NoteReader.ipa
.github/workflows/pages.yml CI: publish web/ to GitHub Pages
```

---

## Web app (zero cost, no cable)

**Link:** <https://thelowke-cloud.github.io/Marty/>

Every push that touches `web/` redeploys it automatically (workflow **Deploy web app**).
The first deploy needs GitHub Pages enabled once: the workflow tries to enable it itself; if it
fails with a permissions error, open **Settings → Pages → Build and deployment → Source** and
choose **GitHub Actions**, then re-run the workflow.

**On her iPhone**

1. Open the link in **Safari** (it has to be Safari, not Chrome, for the next step).
2. Tap **Share** (the square with the arrow at the bottom), scroll down, tap **Add to Home Screen**, tap **Add**.
3. Open **Note Reader** from the home screen. It runs full-screen like a normal app, works offline,
   and keeps her stats on the phone.

Differences from the native app: no haptics (iPhone Safari doesn't support vibration), and sound
starts after the first tap because browsers require a gesture to unlock audio. Everything else
is the same: Czech note names, both clefs, both ranges, letters or piano, Practice / Sprint / Streak,
repetition of missed notes, stats and dark mode.

---

## 1. Building and downloading the `.ipa`

Builds run automatically on every push to `main` (and on `claude/**` branches) and can be
started by hand.

**Start a build by hand**

1. GitHub → **Actions** → **Build IPA** → **Run workflow** → pick the branch → **Run workflow**.

**Download the `.ipa`**

- **From a workflow run:** Actions → open the latest green run → scroll to **Artifacts** →
  download **NoteReader-ipa** → unzip it, you get `NoteReader.ipa`.
- **From a Release:** push a tag that starts with `v`, e.g.

  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```

  The workflow then creates a GitHub **Release** with `NoteReader.ipa` attached, so you can
  download it straight from the Releases page (no unzip needed).

If a build is red, open the run, expand **Archive (unsigned)**, and read the lines that contain
`error:`. The full `xcodebuild` log is also uploaded as the **xcodebuild-log** artifact.

---

## 2. Installing on an iPhone from Windows with Sideloadly

The `.ipa` is unsigned. Sideloadly signs it with an Apple ID at install time.

**One-time setup on the PC**

1. Install **iTunes** and **iCloud** for Windows — use the **non-Microsoft-Store versions**
   from Apple's website (the Store versions don't expose the USB driver Sideloadly needs).
2. Install **Sideloadly** from <https://sideloadly.io>.

**Install the app**

1. Plug the iPhone into the PC with a cable. On the phone tap **Trust this computer** and enter the passcode.
2. Open Sideloadly. The phone should appear in the device list.
3. Drag `NoteReader.ipa` into Sideloadly (or click the IPA icon and choose the file).
4. Enter an **Apple ID** (a throwaway/secondary Apple ID is fine — it does not have to be the one
   used on the phone). Click **Start**, enter the Apple ID password when asked
   (and an app-specific password / 2FA code if prompted).
5. Wait for "Done".

**On the iPhone**

1. **Settings → Privacy & Security → Developer Mode → on.** The phone restarts and asks you to
   confirm. (iOS 16+; on iOS 15 this step doesn't exist.)
2. **Settings → General → VPN & Device Management** → tap the profile with the Apple ID's
   email → **Trust**.
3. Open **Note Reader** from the home screen.

---

## 3. The 7-day limit (free Apple ID)

Apps signed with a free Apple ID **expire after 7 days**. After that the icon still shows but
the app won't open. Your stats and settings are **not lost**: re-installing with the same
bundle ID (`com.lowke.notereader`) keeps the app's data.

Two ways to refresh:

- **Sideloadly again:** plug in the phone and install the same (or a newer) `.ipa` again.
  Takes a minute, keeps data.
- **AltStore + AltServer:** install [AltServer](https://altstore.io) on the PC and AltStore on
  the phone; install the `.ipa` through AltStore. As long as the PC with AltServer is on the same
  Wi-Fi, AltStore refreshes the signature automatically in the background, so the 7 days never
  run out. (A free Apple ID can hold at most 3 sideloaded apps at a time.)

---

## 4. Future: paid Apple Developer account + TestFlight

With a paid developer account ($99/year) the app can be distributed via TestFlight: no cable,
no 7-day limit, updates arrive through the TestFlight app. **No code changes are needed**, only
signing:

1. In `project.yml`, set the team and keep automatic signing:

   ```yaml
   settings:
     base:
       DEVELOPMENT_TEAM: ABCDE12345   # your Team ID
       CODE_SIGN_STYLE: Automatic
   ```

2. In `.github/workflows/build.yml`, replace the unsigned archive + zip steps with a signed
   archive and an export step:
   - Put the distribution certificate (`.p12`), its password, the provisioning profile and an
     App Store Connect API key into GitHub **Secrets**; install them on the runner
     (e.g. with `apple-actions/import-codesign-certs`).
   - Run `xcodebuild archive` **without** the `CODE_SIGNING_ALLOWED=NO …` flags.
   - Run `xcodebuild -exportArchive -exportOptionsPlist ExportOptions.plist` with
     `method: app-store` to produce a signed `.ipa`.
   - Upload it with `xcrun altool --upload-app` or `apple-actions/upload-testflight-build`.
3. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` for each upload.

---

## How the app works

- **Note naming:** Czech, octave-exact. Velká `C … H`, malá `c … h`, jednočárková `c1 … h1`,
  dvoučárková `c2 … h2`. Middle C = `c1`. Answer buttons and piano keys are octave-exact
  (`e1` and `e2` are different).
- **Ranges:** Beginner — treble `c1–g2`, bass `F–c1` (only the `c1` ledger line).
  Intermediate — treble `a–c3`, bass `C–e1` (two ledger lines each way).
  The full note → staff-position table for both clefs is in `NoteReader/Models/Clef.swift`.
- **Repetition:** a missed note comes back after two other notes ("Again — this one tripped you
  up"). Each miss raises its weight (max 3), each correct answer lowers it. Poorly-known and slow
  notes are drawn more often. Never the same note twice in a row.
- **Modes:** Practice (endless, accuracy + average time), Sprint (60 s, +1/−1, personal best per
  clef + range), Streak (until the first mistake, best streak saved).
- **Feedback:** blue flash + light haptic for correct, orange flash + error haptic for wrong
  (the correct name is shown for ~1.3 s). The note's pitch plays after every answer.
- **Audio:** `AVAudioEngine` + `AVAudioSourceNode` synth, `.ambient` session — the silent switch
  mutes it and your music keeps playing.
- **Persistence:** per-note stats, weights, sprint bests and streak bests are stored as JSON in
  `UserDefaults`; settings are stored per key. Everything survives restarts and starts empty
  without crashing.
