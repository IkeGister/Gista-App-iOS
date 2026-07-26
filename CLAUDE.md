# Project: Gista (iOS)

Share a web page — Wikipedia first — and get a spoken version you press play on.

> Gista reads a page and hands you back a spoken gist. Press play, keep moving.

**Product thesis (founder, 2026-07-25):** *"it was almost easier for me to start building this than to read the wiki."* Reading Wikipedia is a chore people avoid; listening to it is something they actually do. Everything in v1 serves that and nothing else.

**Positioning constraint — load-bearing:** *"not meant to be in-depth like NotebookLM — straightforward reading."* Gista **reads**; it does not analyse. No summarization, no Q&A, no chat-with-the-page. See the spec's §15 for the two-axis ladder (coverage vs delivery) and why an LLM belongs only on the delivery axis, as a persona/"Reader", never as a comprehension step.

---

## Start every session by reading

1. `chronicles/HANDOFF.md` — what happened last, what's next, what's blocking. **Read this first.**
2. `.planning/LESSONS.md` — Active Rules. Environment traps that will waste your time if you rediscover them.
3. `docs/superpowers/specs/2026-07-25-gista-v1-elevenlabs-readout-design.md` — the authoritative v1 design.

---

## Quick reference

| | |
|---|---|
| Build | `xcodebuild -project Gista/Gista.xcodeproj -scheme Gista -destination 'platform=iOS Simulator,name=iPhone 16' build` |
| Typecheck without building | see below — the reliable verification while the platform is missing |
| M1 pipeline spike | `/usr/bin/python3 scripts/gist_spike.py "https://en.wikipedia.org/wiki/Voyager_1"` |
| Spike, no TTS spend | add `--script-only` |
| Read the API key | `security find-generic-password -s elevenlabs-api-key -w` (never print it) |

**⚠️ `xcodebuild` currently fails outright** — the iOS platform is not installed on this machine (no simulator runtimes, no destinations). Fix: `xcodebuild -downloadPlatform iOS`. Until then, verify code with:

```bash
cd Gista
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun swiftc -typecheck -swift-version 5 -target arm64-apple-ios18.0 -sdk "$SDK" \
  $(grep -rLn "^import Shared" $(find Gista Shared -name '*.swift' -not -path '*/Preview*'))
```

Expect one unavoidable error: `no such module 'FirebaseCore'` (external package, unresolvable by raw `swiftc`). Anything else is real. Note zsh does **not** word-split unquoted `$VAR` — inline the `find` in command substitution as above.

---

## Architecture

SwiftUI + MVVM, iOS 18 floor, `SWIFT_VERSION = 5.0` (not Swift 6 mode — but new code is written Swift-6-clean).

**The pipeline:** shared URL → `WikipediaService` (lead extract) → script persisted → `TTSProviding` → audio file → `PlayerEngine`.

**Access points (how gists get created).** The **share extension is a retained, first-class feature** — sharing a link into Gista from Safari, the Wikipedia app, or anywhere else is v1's primary way to create a gist. The `GistaShare` target stays; only its server call (`LinkSender` → the dead `/links/store`) is removed, replaced by local validate-and-enqueue through the app group. Do not mistake "the backend comes off" for "the extension comes off."

**Two principles that explain most decisions:**

1. **Script text is the durable source of truth; audio is a derived, evictable cache.** Text is KB and permanent, audio is MB and disposable. Therefore *regeneration is a normal path, not an error path* — pressing play on a pruned gist re-enters the same voicing flow with the same progress states. One pipeline, two entry points.
2. **One playback engine, many surfaces.** `PlayerEngine` owns all player state. `PlaybackView`, `MiniPlalyerView`, the lock screen / AirPods / CarPlay (`MPNowPlayingInfoCenter`), and later the Live Activity are all *views onto it*. Never a second playback implementation.

**Persistence:** `GistSource` (durable, one per article) → `@Relationship(.cascade)` → `GistRendition` (one *reading* of that source). v1 always creates exactly one rendition, `readerID = "straight"`. The one-to-many exists so persona Readers arrive later without a migration. Audio cache identity is `revisionID + readerID + voiceID`.

**A Reader = persona (script style) + voice (vocal delivery)**, chosen as one unit. v1 ships one: "Straight" — no transform, voice Daniel.

---

## Key paths

| What | Where |
|---|---|
| App target source | `Gista/Gista/App/` |
| Persistence models | `Gista/Gista/App/Models/GistRecord.swift` (`GistSource`, `GistRendition`) |
| Container | `Gista/Gista/App/ApplicationMain/GistaModelContainer.swift` |
| Script source | `Gista/Gista/App/Services/WikipediaService.swift` |
| TTS seam + providers | `Gista/Gista/App/Services/TTS/` |
| Audio cache + eviction | `Gista/Gista/App/Services/FileManagerService.swift`, `Services/Storage/` |
| Playback | `Gista/Gista/App/Services/Playback/` |
| Share extension | `Gista/GistaShare/` |
| Shared framework | `Gista/Shared/` |
| Spec | `docs/superpowers/specs/` |

**Stale duplicates:** repo-root `Shared/` and `GistaShare/` are **outside the build**. The project compiles `Gista/Shared/` and `Gista/GistaShare/`. Always confirm which copy is in the target before editing.

---

## Conventions

- Existing filename typo `MiniPlalyerView.swift` is **intentional to preserve** — do not rename.
- New app-target files must **not** go in `Gista/Shared/Models/` (that's the Shared *framework*; existing files there are carved into the app target one-by-one in the pbxproj). App-only models go in `Gista/Gista/App/Models/`.
- The project uses Xcode **buildable folders** (`PBXFileSystemSynchronizedRootGroup`, objectVersion 77) — new files in synchronized folders are picked up automatically, **no `project.pbxproj` edit needed**. This is what makes parallel agent work safe.
- Secrets never live in files. The ElevenLabs key lives in the macOS Keychain (`elevenlabs-api-key`); `Secrets.xcconfig` is generated and gitignored.
- Firebase/auth/onboarding code is **dormant, not deleted** — call sites removed, code still compiles.

## ⛔ DO NOT TOUCH protocol

Files with a `⛔ DO NOT TOUCH ⛔` header require explicit permission to modify — no exceptions, including "harmless additive" changes. None exist in this repo yet.

---

## Notes

- **ElevenLabs is on the free tier.** ~10,000 credits/month, and `eleven_flash_v2_5` bills at **0.5 credits per character** (so ~29 Wikipedia leads/month). Quota was exhausted 2026-07-25; **resets 2026-08-14**. All tests use `FixtureTTSProvider` so they never spend quota.
- Voice: Daniel `onwK4e9ZLuTAKqWW03F9` ("Steady Broadcaster"). **Not** Rachel — she isn't in this account and returns 402.
- `eleven_flash_v2_5` speaks at ~**117 wpm** (measured), not the usual ~150 estimate. Matters for any duration shown before audio exists.
- The Firebase Cloud Functions backend (`us-central1-dof-ai.cloudfunctions.net/api`) is **being retired**. It was CrewAI scaffolding for orchestration that Claude Agent SDK now handles natively. Nothing in v1 calls it; `GistaService` stays dormant.
