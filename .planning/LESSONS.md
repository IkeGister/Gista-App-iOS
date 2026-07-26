# Lessons

## Active Rules
<!-- Read these FIRST at every session start. One-liners only. -->

- [2026-07-25] Deployment target is **iOS 18.0** (all 4 build configs in `Gista/Gista.xcodeproj/project.pbxproj`) — `AppDocs/Architecture.md` claims "iOS 16.0+" and is STALE; trust build settings, not AppDocs
- [2026-07-25] Sample gist data is `Gist.previews` (not `sampleGists`) and only reaches SwiftUI previews — `LibraryView`'s production path renders an empty library, so "no content" is expected, not a bug
- [2026-07-25] Repo-root `Shared/` and `GistaShare/` are STALE duplicates outside the build — the project compiles `Gista/Shared/` and `Gista/GistaShare/`; always confirm which copy is in the target before editing
- [2026-07-25] Use `/usr/bin/python3` for any HTTPS script — the python.org Python 3.11 at `/usr/local/bin/python3` has no CA bundle and fails `CERTIFICATE_VERIFY_FAILED`, and `certifi` is not installed
- [2026-07-25] Wikipedia REST API returns **403** to default Python/curl User-Agents — always send an explicit `User-Agent` header
- [2026-07-25] The ElevenLabs API key in Keychain (`elevenlabs-api-key`) is **scope-limited**: TTS works, but `user_read` and `voices_read` are missing, so `/v1/user`, `/v1/user/subscription`, and `/v1/voices` all 401 with `missing_permissions`
- [2026-07-25] ElevenLabs **free tier cannot use library voices via API** (402 `paid_plan_required`) — including Rachel `21m00Tcm4TlvDq8ikWAM`; a paid plan or an account-owned voice is required for any TTS spike
- [2026-07-25] Never store the ElevenLabs key in a file — read it at runtime via `security find-generic-password -s elevenlabs-api-key -w`; `Secrets.xcconfig` is gitignored and generated, never committed
- [2026-07-25] Rachel `21m00Tcm4TlvDq8ikWAM` is NOT in this account — use `premade` category voices (e.g. Daniel `onwK4e9ZLuTAKqWW03F9` "Steady Broadcaster"); check `GET /v1/voices` before hardcoding any `voice_id`
- [2026-07-25] `eleven_flash_v2_5` speaks at **~117 wpm**, not the ~150 wpm rule of thumb (measured: 110 words → 56.3s) — use 117 for any duration shown before audio exists, e.g. in the Live Activity
- [2026-07-25] ElevenLabs `character_count` lags after a synthesis — it still read 9343/10000 immediately after a successful 613-char call; don't gate logic on a fresh read of remaining quota
- [2026-07-25] **IDE diagnostics on this project lie.** SourceKit typechecks single files against the **macOS** SDK, so `'AVAudioSession' is unavailable in macOS` and `Cannot find <Type> in scope` are usually noise. Verify for real with: `xcrun swiftc -typecheck -target arm64-apple-ios18.0 -sdk $(xcrun --sdk iphoneos --show-sdk-path) <files...>` — pass every file in the dependency group together or cross-file references will "fail" spuriously
- [2026-07-25] Project is **`SWIFT_VERSION = 5.0`**, NOT Swift 6 language mode (despite Xcode 26.6) — strict-concurrency errors you'd expect in Swift 6 won't fire; writing Swift-6-clean code is still safe and preferred
- [2026-07-25] Do NOT add new app-target files to `Gista/Shared/Models/` — that folder belongs to the **Shared framework**, and every existing file in it is carved into the app target one-by-one via `PBXFileSystemSynchronizedBuildFileExceptionSet` in the pbxproj. A new file there is app-invisible without `import Shared` + `public`, or a forbidden pbxproj edit. App-only models go in `Gista/Gista/App/Models/`
- [2026-07-25] `LaunchScreen` does not self-dismiss — it waits for a tap on dev buttons that appear after 3s. Anything wanting a pure splash must call `onboardingViewModel.dismissLaunchScreen()` on a timer

## Detail

### ElevenLabs: free tier + scoped key blocks TTS (2026-07-25)
- **Symptom:** `POST /v1/text-to-speech/{voice}` → 402 `{"code":"paid_plan_required","message":"Free users cannot use library voices via the API"}`. Follow-up diagnosis via `/v1/voices` → 401 `missing_permissions` (`voices_read`).
- **Cause:** Two independent issues. (1) The account is on the free plan, which gates library/community voices behind payment for API use. (2) The API key was created with a narrow scope that excludes `user_read` and `voices_read`, so plan and voice inventory can't be queried to work around it.
- **Fix:** Grant `voices_read` + `user_read` to the key at https://elevenlabs.io/app/settings/api-keys (free, enables discovery of any account-owned voice that free tier permits), and/or move to a paid plan for library-voice access.
- **Prevention:** Before designing around a specific `voice_id`, verify with `GET /v1/voices` that the account can actually use it. Discovered during the M1 pipeline spike — which is exactly why M1 exists ahead of any Swift work.

### python.org Python has no CA certificates (2026-07-25)
- **Symptom:** `ssl.SSLCertVerificationError: unable to get local issuer certificate` on any HTTPS request from `/usr/local/bin/python3` (3.11).
- **Cause:** The python.org macOS installer ships CA certs but requires running `Install Certificates.command`, which was never run on this machine. `certifi` is also absent.
- **Fix:** Invoke scripts with `/usr/bin/python3` (uses the macOS system trust store).
- **Prevention:** Repo scripts should be run with `/usr/bin/python3`; don't assume `python3` on PATH has working TLS.
