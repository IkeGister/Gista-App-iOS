# HANDOFF — start here

**Last session:** 2026-07-25
**Branch:** `feat/v1-elevenlabs-readout`
**Milestone state:** M1 ✅ done · M2 built, unverified · M3–M6 not started

---

## The one thing blocking everything

**The iOS platform is not installed on this machine.** Xcode 26.6 is present, but there are no simulator runtimes and no build destinations, so `xcodebuild` refuses before it even compiles. Nothing can be built or run until:

```bash
xcodebuild -downloadPlatform iOS
```

(Multi-gigabyte; the founder was clearing disk space for it when this session ended. It usually asks for a password.)

**First action on return:** confirm the platform installed, then run the first real build. Every item under "Next up" assumes a working build.

---

## What happened this session

The project pivoted and then got most of a v1 built.

**The pivot.** Gista had a Firebase Cloud Functions backend that produced "gists" server-side. It comes off. It turned out to be CrewAI scaffolding for agentic orchestration that Claude Agent SDK now handles natively — so removing it is a subtraction, not a redesign. ElevenLabs now produces v1 audio directly.

**M1 — the pleasantness spike. PASSED.** Run as a Python script (`scripts/gist_spike.py`), not in-app — which turned a multi-day milestone into minutes. Two real articles synthesised and heard: `Voyager 1` and `Murphy v. NCAA`. Founder's verdict: *"hells yes it was useful… it was almost easier for me to start building this than to read the wiki."* That sentence is now the product thesis.

Along the way M1 earned its keep by finding blockers cheaply: Rachel isn't in the account (402), the API key was scoped too narrowly, the free tier bills flash at 0.5 credits/char, and python.org's Python has no CA certificates.

**M2 — built by four parallel agents, integration verified by typecheck.** All four landed with **zero cross-agent API mismatches**, which is the notable part: strict file ownership plus value-type boundaries (player takes a `PlayableGist`, cache takes opaque UUIDs, neither imports SwiftData) meant nothing had to be renegotiated.

- **Persistence** — `GistSource` + `GistRendition` (one source, many readings), model container wired, both auth gates removed, Firebase init and notification prompt removed, `Item.swift` deleted.
- **Script + voice** — `WikipediaService` with typed errors; `TTSProviding` seam; live ElevenLabs provider (Daniel, 5000-char cap, 401/402/429 handling); `FixtureTTSProvider` so tests never spend quota.
- **Audio cache** — `FileManagerService` actor over Application Support (backup-excluded), plus *pure* LRU eviction and orphan-sweep functions that touch neither disk nor SwiftData.
- **Playback** — `PlayerEngine` + `AudioSessionController` + `NowPlayingController`: interruptions with `.shouldResume` discipline, route-change pause, media-services-reset recovery, remote commands, and a regeneration seam for pruned audio.

**Direction clarified mid-build** (and folded into the schema before it hardened): the future is *multiple readings of one source* — persona "Readers" that add flavour, possibly including an adversarial reader that counters each claim. That is a **delivery** axis, not an analysis axis. Gista reads; it does not analyse.

---

## Known problems, all pre-existing, all mine to fix

These need `project.pbxproj` edits, which is why the agents were barred from them. Do them with a working build so each can be verified rather than guessed.

1. **Both `INFOPLIST_FILE` references point at files that do not exist** — `Gista/Info.plist` and `GistaShare/Info.plist`, while `GENERATE_INFOPLIST_FILE = YES` is also set. Contradictory. Unknown whether it breaks the build. **Check this first — it may be why nothing else works.**
2. **No `UIBackgroundModes: audio`** — background and lock-screen playback will silently stop. Fatal for an audio app, trivial to fix.
3. **No path for the ElevenLabs key to reach the app** — the provider correctly throws `.missingAPIKey`. Needs Keychain → generated `Secrets.xcconfig` → `INFOPLIST_KEY_ElevenLabsAPIKey`.

---

## Next up, in dependency order

1. **Verify the build.** Fix whatever the three problems above actually cause.
2. **`GistPipeline`** — the missing centre. A serial actor with two entry points (`ingest(url:)`, `regenerateAudio(for:)`) sharing one state machine, where `.scriptReady` doubles as the post-eviction state so regeneration traverses the same edges as first production. Wires all four M2 components together. Nothing else can be finished without it.
3. **Composition root** — instantiate `PlayerEngine`, choose real vs fixture TTS provider (`FixtureTTSProvider.isSelectedByLaunchArgument` checks `-UseFixtureTTS`), wire `PlayerEngine.regenerationHandler` to `GistPipeline.regenerateAudio`.
4. **UI rewire (M4 in part)** — `LibraryViewModel` (still an empty stub) and `LibraryView` onto real records; `PlaybackView` and `MiniPlalyerView` onto `PlayerEngine`, replacing the mock `isPlaying` toggle.
5. **M3 — share sheet. The share extension is a RETAINED feature and v1's primary access point** — sharing a link into Gista from another app is how gists get created. The `GistaShare` target, `ShareViewController`, and `ShareViewControllerVM` all stay.
   What changes is only what happens *after* the user taps share: instead of POSTing to a server, the extension validates the URL and enqueues it locally via the app group, and the app drains that queue into `GistPipeline`. Concretely: delete **only** `LinkSender.swift` (plus `LinkResponse`/`LinkError` if nothing else uses them) because it targets the dead `/links/store`; move `WikipediaURL.parse` into the `Shared` framework so the extension and app validate identically; add a clear in-extension rejection message for non-Wikipedia URLs.
6. **M5 — eviction integration** + `BGTaskScheduler` janitor.
7. **M6 — Live Activity.** New `GistaWidgets` target; this one *does* need pbxproj work and must be sequential.

---

## Open threads

- **ElevenLabs plan.** Free tier gives ~29 articles/month and quota resets **2026-08-14**. Everything can be built and tested against fixtures, but *hearing* it again — new voices, real durations, an end-to-end share-sheet run — needs the paid plan. This is the only thing between "built in a few days" and "shipped in a few days."
- **Was iOS 18.0 deliberate?** All four build configs say so; `AppDocs/Architecture.md` claims 16.0 and is stale. Founder said he isn't concerned about older users, so treat 18.0 as intentional unless told otherwise.
- **The spec's persona section is over-long** for a v1 document — founder flagged not to over-invest there. Compress §15 next time the spec is touched.
- **`AppDocs/` is stale generally** (it predates the pivot and asserts a backend that's being removed). Decide whether to update or retire it.
- **Stale duplicate directories** — repo-root `Shared/` and `GistaShare/` are outside the build. Post-v1 housekeeping.
