# EnerGrow 1.2.3 (build 7)

This release includes fixes and usability improvements for PLTS energy monitoring.

## Changes

- The stale telemetry threshold selected in Settings now applies consistently to alert evaluation, device cards, and the Overview summary.
- CCTV playback can be opened in landscape fullscreen, with an on-screen control to exit fullscreen.
- Settings reads the displayed app version from installed package metadata, keeping it aligned with the built APK.
- Updated product documentation and complete version history are included in `CHANGELOG.md`.

## Install

Download `EnerGrow-v1.2.3.apk` and install it on an Android device. If Android reports that the app cannot be updated because its signature differs, remove the older installation first. Removing it clears locally stored session and preferences; sign in again after installation.

## Verification

- `flutter analyze` passed.
- `flutter test` passed (2 tests).
- Release APK built with the configured Android upload keystore.
- Installed and launched on Android device 24090RA29G; Package Manager reported version 1.2.3, build 7.
