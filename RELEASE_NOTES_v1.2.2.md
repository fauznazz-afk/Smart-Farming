# EnerGrow 1.2.2

This release adds energy summaries and configurable dashboard alerts, and makes CCTV playback user controlled.

## What's new

- See estimated daily and seven-day solar production and AC consumption, compared with the previous equivalent period.
- Configure in-app warnings for low battery state of charge and stale telemetry.
- CCTV now opens in standby. Press **Play kamera** to start the stream; stop, retry, and reload controls are available while viewing.
- Reduced unnecessary dashboard rebuilds during periodic data refresh.

## Notes

- Energy values are estimates calculated from recorded power history.
- Alerts appear while the app is open. Push notifications while the app is closed require server-side FCM or ThingsBoard notification setup.
