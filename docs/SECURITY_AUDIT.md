# Security audit — PLTS Monitoring (EnerGrow)

Date: 30 October 2026
Scope: source code (`lib/`, `android/app/src/main/`), not a runtime or APK assessment.
Method: manual read of the credential, transport, WebView, updater and storage paths, plus the existing test suite.

## Verdict

No critical findings. The security-relevant paths are guarded, and the guards are centralised at the points every call site inherits. The residual items below are hygiene, not holes.

## Verified controls

| Area | Control | Where |
|---|---|---|
| ThingsBoard session token | Stored in `flutter_secure_storage`; pre-1.7 plaintext `SharedPreferences` copies purged and verified with `reload()` | `services/thingsboard_api.dart` |
| Request destination | `_matchesBaseUrl` checks host + scheme + port in `_send`, so all six `Uri.parse` sites inherit it | `services/thingsboard_api.dart` |
| Redirects | Refused on both the REST and AI clients; the token cannot be replayed to a redirect target | `_send`, `ai_chat_service.dart` |
| Response size | Fold caps snapshots (256 KiB), history (4 MiB) and AI replies (256 KiB) — DoS mitigation against a compromised endpoint | `_send`, `ai_chat_service.dart` |
| WebSocket | Refuses to derive `ws://`; token only appended when non-empty | `services/thingsboard_api.dart` |
| CCTV URL | Strict allowlist: https, exact host, port 443, no userinfo, `/stream.html`, `src` matching `^[A-Za-z0-9_-]{1,64}$` (blocks `?src=rtsp://…` SSRF) | `services/cctv_url.dart` |
| CCTV WebView | Navigation pinned to the camera origin via `isAllowedCctvNavigation`; no `loadHtmlString`/`runJavaScript` from user input | `screens/cctv_screen.dart` |
| AI endpoint | HTTPS-only, no userinfo, redirects refused; API key only in a header, never logged or echoed | `ai_chat_service.dart`, `utils/ai_provider.dart` |
| Prompt injection | System prompt instructs the model to treat telemetry and the question as data, never commands | `utils/ai_provider.dart` |
| Screenshot guard | `FLAG_SECURE` reference-counted, released on route cover via `RouteObserver` | `services/secure_window.dart`, `MainActivity.kt` |
| Native alarm host | `requireAllowedThingsBoardHost`: https, exact host, no userinfo, port 443, no path | `alarm/AlarmRule.kt` |
| Backup / D2D | `allowBackup="false"` plus blanket per-domain excludes | `AndroidManifest.xml`, `res/xml/` |
| Signing material | `key.properties` and `*.jks` git-ignored and untracked | `android/.gitignore` |
| Updater | Does not download or install; opens the release page. URL validated https | `utils/app_update.dart` |

## Residual items

1. **`AppRelease.url` invariant now enforced at the type.** The parser already refused non-https, but two screens hand the value to `launchUrl` and a test fixture builds `AppRelease` directly. The constructor now asserts `https://`, and `test/app_update_test.dart` covers it. (Closed in this audit.)
2. **`catch (_) {}` in ~19 places**, mostly cache reads where a fallback is intended. No security impact; a few would benefit from `appLog` for debuggability.
3. **Hardcoded device UUIDs** in `thingsboard_api.dart`. Not secrets, but they disclose topology to anyone with the APK. Acceptable for a single-tenant app.
4. **`flutter_secure_storage` options pinned.** All three stores (`thingsboard_api.dart`, `cctv_url.dart`, `ai_settings.dart`) now pass `AndroidOptions(encryptedSharedPreferences: true)` explicitly. Behaviour is unchanged; the option makes the requirement legible and survives a future change to the plugin default. (Closed in this audit.)

## APK scan

Release APK scanned for bundled secrets.

- No zip entry matching `key`, `secret`, `.env`, `keystore`, `jks`, `pem`, or `credential`.
- No PEM private key header (`-----BEGIN ... PRIVATE KEY-----` count: 0). The `RSA PRIVATE KEY` / `EC PRIVATE KEY` strings are algorithm labels in a crypto library's string table, adjacent to `ENCRYPTED PRIVATE KEY` and locale names.
- 33 `CERTIFICATE` markers are the public CA bundle.

## Out of scope

- Server-side token rotation and expiry on the ThingsBoard instance.
- TLS configuration of `dashboard.mbkm20262027.tech`.
