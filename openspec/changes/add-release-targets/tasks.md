Task groups map to the commit sequence. The user commits; do not run `git commit`.

Reference: `docs/Flutter_Port_Tech_Doc.md` §6 Phase 7 and §8, the definition of done.

Depends on `add-parity-gaps-and-platform-pass` — this verifies the finished app.

This phase changes no behavior. If a platform surfaces a bug, fix it as its own change rather than
folding it in here (`design.md`).

## 1. Smoke test harness

- [ ] 1.1 Add `integration_test` as a dev dependency
- [ ] 1.2 Add one boot-and-tap smoke test: launch, perform a basic interaction, assert something
      rendered. Keep it thin — its job is catching a platform that stopped launching, not re-testing
      behavior the unit suites already cover
- [ ] 1.3 Confirm it passes on the development machine before touching any platform

## 2. Android

- [ ] 2.1 Configure the Android target; build a release-mode APK
- [ ] 2.2 Run the smoke test on a real device, not only an emulator
- [ ] 2.3 Checklist: data survives a restart; backgrounding and resuming works; plan resolution fires
      on resume; the backgrounding flush reaches disk
- [ ] 2.4 Record results and capture screenshots

## 3. iOS

- [ ] 3.1 Configure the iOS target; build for a real device
- [ ] 3.2 Run the smoke test on real hardware — the lifecycle and storage behavior this port depends
      on is what simulators reproduce least faithfully (`design.md`)
- [ ] 3.3 Checklist: same as Android
- [ ] 3.4 Record results and capture screenshots

## 4. macOS

- [ ] 4.1 Configure the macOS target and build
- [ ] 4.2 Run the smoke test
- [ ] 4.3 Checklist: data survives a restart; window resizing switches between the bar and rail
      layouts; the stats range controls are present — V1 shipped macOS without them
- [ ] 4.4 Record results and capture screenshots

## 5. Web

- [ ] 5.1 Confirm the wasm database assets are served correctly
- [ ] 5.2 Build and run the smoke test in a browser
- [ ] 5.3 Checklist: data persists across a page reload, which exercises the web database backend
      rather than the UI; the analysis pass computes on its synchronous path without blocking
      visibly
- [ ] 5.4 Record results and capture screenshots

## 6. Windows

- [ ] 6.1 Configure the Windows target and build
- [ ] 6.2 Run the smoke test
- [ ] 6.3 Checklist: data survives a restart; window resizing switches layouts
- [ ] 6.4 Record results and capture screenshots

## 7. Documentation and close-out

- [ ] 7.1 Write `README.md` — the repository has none. Describe the app, the package layout, and how
      to run and test it
- [ ] 7.2 Add the screenshots to `docs/`
- [ ] 7.3 Verify the definition of done in `docs/Flutter_Port_Tech_Doc.md` §8: domain suite at parity
      with the Swift suite plus the fixed-defect regressions; every V1 feature working on Android,
      iOS, macOS and web; no `double` money; no unclamped date math; analyzer clean under strict mode
- [ ] 7.4 Confirm the §5 decisions the master doc reserves space for are recorded inline: the
      occurrence-id normalization and the totals ruling
- [ ] 7.5 Run the full suites one final time: `cd packages/domain && dart analyze && dart test` and
      `cd app && flutter analyze && flutter test`
