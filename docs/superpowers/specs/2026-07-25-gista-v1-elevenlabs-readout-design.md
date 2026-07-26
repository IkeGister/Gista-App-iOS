# Gista v1 — ElevenLabs Readout: Design Spec

**Date:** 2026-07-25
**Status:** Authoritative design for the v1 pivot
**Repo:** `/Users/ikenlemadim/Documents/5DOF Projects/Gista App` (branch `main`)
**Xcode project:** `Gista/Gista.xcodeproj` — targets `Gista` (app), `GistaShare` (share extension), `Shared` (framework), plus `GistaTests`, `GistaUITests`, `SharedTests`

---

## 1. One-line summary

Share a Wikipedia page from the iOS share sheet; Gista fetches the article's hand-written lead extract, voices it once through ElevenLabs, stores everything locally, and hands you a play button — no server, no sign-in, no LLM.

## 2. v1 behavior, flatly

1. User is reading a Wikipedia article in Safari and taps Share → Gista.
2. The share extension validates the URL is a Wikipedia article page, drops it into the app-group queue, and confirms ("Added to Gista"). No network call happens in the extension.
3. Next time the Gista app is opened (or foregrounded), it drains the queue: for each URL it creates a `GistRecord`, fetches the Wikipedia lead extract (`GET https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}`), persists the extract text via SwiftData, then calls ElevenLabs TTS once and writes the resulting MP3 to disk.
4. The library shows the gist immediately with a live production status ("Reading page…" → "Voicing…" → ready). Statuses reuse the existing `GistStatus.productionStatus` concept.
5. User taps the gist → `PlaybackView` plays the MP3 through the single audio engine. `MiniPlalyerView` shows the same playback state. Lock screen / AirPods / CarPlay controls work via `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`. Leaving the app starts a Live Activity with play/pause.
6. Audio files are a cache under a storage budget. If a gist's audio was evicted (or generation failed), tapping play re-enters the voicing stage of the same pipeline with the same progress UI, using the persisted script text. Script text is never deleted except when the user deletes the gist.
7. No sign-in anywhere in this loop. Auth code stays in the repo, dormant.

---

## 3. Verified repo state (what this spec builds on)

Verified 2026-07-25 by reading the code. Corrections to prior assumptions are marked ⚠.

| Item | State |
|---|---|
| `Gista/Gista/App/Services/FileManagerService.swift` | Empty (7-line header comment). To be filled in. |
| `Gista/Gista/App/ViewModels/LibraryViewModel.swift` | Empty (7-line header comment). To be filled in. |
| `Gista/Gista/App/Views/MiniPlalyerView.swift` | Type is `MiniPlayerView`; `isPlaying` is a bare `@State` Bool, hardcoded title/duration, no audio. Filename typo stays — do not rename the file. |
| Audio | No `AVFoundation`, `AVAudioPlayer`, `AVPlayer`, or `MPNowPlayingInfoCenter` anywhere in the codebase. |
| SwiftData | Not wired. `Gista/Gista/Item.swift` is the untouched Xcode template. `ContentView` imports SwiftData but uses nothing. No `.modelContainer` anywhere. No persistence exists. |
| ActivityKit / App Intents | None anywhere. |
| ⚠ Deployment target | `IPHONEOS_DEPLOYMENT_TARGET = 18.0` in **all four** build configurations in `project.pbxproj` — not iOS 16 as previously believed. Consequence: interactive Live Activities, `LiveActivityIntent`, and all SwiftData features are unconditionally available; no graceful-degradation branches are needed. This spec does **not** change the deployment target. The settled principle behind the old "iOS 16 floor" decision — in-app playback carries the product, Live Activity is additive — stands unchanged. |
| ⚠ Sample data | `Gista/Shared/Models/Gists/GistExtensions.swift` defines `Gist.previews` (not `sampleGists`), with fake `example.com/audio1.mp3` URLs. `LibraryView` takes injected `articles: [Article]`, `gists: [Gist]` defaulting to `[]`; production path (`ContentView` → `LibraryView()`) shows an **empty** library; previews inject `Gist.previews`. |
| ⚠ Duplicate directories | Repo root contains stale `Shared/` and `GistaShare/` directories. The Xcode project's groups resolve relative to `Gista/`, so the **built** sources are `Gista/Shared/` and `Gista/GistaShare/`. The root copies are dead weight outside the build (cleanup noted in §12, not required for v1). |
| Share extension | `ShareViewController` + `ShareViewControllerVM` load `userId` from app group defaults and refuse to work signed-out; `LinkSender` POSTs to `https://us-central1-dof-ai.cloudfunctions.net/api/links/store`. |
| App-group handoff | Already exists: `AppConstants.appGroupId = "group.Voqa.io.Gista"`, `shareQueueKey = "ShareQueue"`. `SharedContentService` (main app) drains the queue on launch/foreground. This is the ingestion transport v1 keeps. |
| Auth gates | Two: `GistaApp.body` (`userCredentials.isAuthenticated` → `OnboardingView`) and a second one inside `ContentView`. Both come off. |
| `GistaService` | Full Firebase Cloud Functions client (users, links, gists, categories). Goes dormant. |
| Models | `Gist` (struct, Codable, with `segments: [GistSegment]`, `status: GistStatus{inProduction, productionStatus}`), `GistSegment{duration,title,audioUrl,segmentIndex}`, `Article`, `GistCategory` — all in `Gista/Shared/Models/`. |
| ElevenLabs | Zero references in the codebase today. |

---

## 4. Architecture

### 4.1 Component map

```
GistaShare (extension)                    Gista (app)
┌──────────────────────┐    app group    ┌─────────────────────────────────────────────┐
│ ShareViewController   │   UserDefaults │  SharedContentService (exists, trimmed)      │
│ ShareViewControllerVM │ ──"ShareQueue"→│        │ ingest(url)                          │
│  (URL validation only)│                │        ▼                                      │
└──────────────────────┘                 │  GistPipeline (new) ── WikipediaService (new) │
                                         │        │                TTSProvider (new,     │
                                         │        │                 protocol; ElevenLabs │
                                         │        │                 impl + Fixture impl) │
                                         │        ▼                                      │
                                         │  SwiftData: GistRecord (new @Model)           │
                                         │  FileManagerService (filled in: audio cache,  │
                                         │        budget, eviction)                      │
                                         │        │                                      │
                                         │        ▼                                      │
                                         │  PlayerEngine (new, singleton)                │
                                         │    ├─ PlaybackView      (rewired)             │
                                         │    ├─ MiniPlalyerView   (rewired)             │
                                         │    ├─ MPNowPlaying / RemoteCommands           │
                                         │    └─ Live Activity (GistaWidgets, new target)│
                                         │  LibraryViewModel (filled in)                 │
                                         └─────────────────────────────────────────────┘
```

Dormant (files stay, no call sites): `GistaService`, `NetworkService` endpoints for the backend, `FirebaseService`, `OnboardingViewModel`/`OnboardingView`/`AppleSignInButton`, `UserCredentials` auth surface, `SubscriptionService`, `GistaServiceViewModel`, the `Views/Debug/GistaService*` test views. Deleted: `LinkSender` (and only `LinkSender`) — see §12.

### 4.2 Units

Every unit below lists: what it does / how it's used / what it depends on. "New" means a new file; "fill in" means writing into an existing empty file; "rewire" means editing an existing view.

**`WikipediaService` — new, `Gista/Gista/App/Services/WikipediaService.swift`**
- Does: turns a shared URL into a script. Parses the URL (accepts hosts matching `*.wikipedia.org`, normalizes mobile hosts `{lang}.m.wikipedia.org` → `{lang}.wikipedia.org`; accepts paths `/wiki/{title}` and `/w/index.php?title={title}`; strips fragments and other queries; keeps the title percent-encoded with underscores as the REST API expects). Calls `GET https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}` with a proper `User-Agent` (`Gista/1.0 (nlemadimtony@gmail.com)`, per Wikimedia API etiquette). Returns `WikipediaSummary { title: String, extract: String, pageURL: URL, thumbnailURL: URL?, lang: String }` or throws typed errors: `.notAWikipediaArticleURL`, `.pageNotFound`, `.disambiguationPage` (response `type == "disambiguation"`), `.emptyExtract` (`extract` missing/blank), `.offline`, `.serverError`.
- Used by: `GistPipeline` only.
- Depends on: `URLSession` behind the existing `NetworkServiceProtocol` style (injectable session for tests). No auth, no key.
- Language handling (decided): the language subdomain of the shared URL is passed through as-is — sharing `fr.wikipedia.org/wiki/Paris` produces a French script voiced by the same multilingual model. No language UI, no translation.

**`TTSProviding` — new protocol, `Gista/Gista/App/Protocols/TTSProviding.swift`**
```swift
protocol TTSProviding {
    /// Returns encoded audio (MP3) for the given text. One call per gist in v1.
    func synthesize(text: String) async throws -> Data
}
```
- `ElevenLabsTTSProvider` (new, `Services/ElevenLabsTTSProvider.swift`): `POST https://api.elevenlabs.io/v1/text-to-speech/21m00Tcm4TlvDq8ikWAM?output_format=mp3_44100_128`, header `xi-api-key`, JSON body `{ "text": ..., "model_id": "eleven_flash_v2_5" }`. Voice (Rachel) and model are compile-time constants in v1 — no voice picker. Enforces `MAX_TEXT_CHARS = 5000` (our self-imposed cap, inherited from the sibling Gaimer project, not an ElevenLabs hard limit; a lead extract of 250–400 words is ~1,500–2,500 chars, far under it). Truncates at the last sentence boundary under the cap rather than erroring — a lead extract will never hit this in practice. Maps HTTP failures to typed errors: 401 → `.invalidKeyOrQuota`, 429 → `.rateLimited(retryAfter:)` (retry **once** after `Retry-After` or 2 s, then throw), 4xx → `.badRequest`, 5xx/URLError → `.serverOrNetwork`.
- `FixtureTTSProvider` (new, lives in the app target under `Services/`, guarded by `#if DEBUG` for the launch-argument path; also used directly by tests): returns a bundled ~10 s MP3 fixture after a simulated 1 s delay. Selected when launch argument `-UseFixtureTTS` is present, or always in unit tests. This is how every day of development after M1 avoids burning ElevenLabs quota.
- Key management (decided): the key lives in the macOS login Keychain under service name `elevenlabs-api-key`. A Run Script build phase (`scripts/generate-secrets.sh`) runs `security find-generic-password -s elevenlabs-api-key -w` and writes `Config/Secrets.xcconfig` (gitignored) containing `ELEVENLABS_API_KEY = ...`; the xcconfig is attached to the `Gista` target's configurations, `Info.plist` gets `ElevenLabsAPIKey = $(ELEVENLABS_API_KEY)`, and the provider reads it from `Bundle.main`. **Stated plainly: an API key embedded in a shipped iOS binary is extractable by anyone with the IPA. This is acceptable for local dev and TestFlight-to-self only.** Before public release, the call moves behind a thin server proxy — the founder already runs exactly this pattern in `Gaimer-app/supabase/functions/managed-voice-tts/index.ts` (server holds `ELEVENLABS_API_KEY`, sends the `xi-api-key` header; the client never sees it). Note that function is currently fail-closed behind a stubbed `validateRequestIdentity` pending its own deploy work order — it is the pattern to copy, not a live endpoint to point at. Because everything upstream talks to `TTSProviding`, swapping device-direct → proxy is a one-file change (`ProxyTTSProvider` replacing `ElevenLabsTTSProvider` in the composition root).

**`FileManagerService` — fill in, `Gista/Gista/App/Services/FileManagerService.swift`**
- Does: owns the audio cache. Directory: `Application Support/Audio/` in the **app container** (not the app group — the extension never touches audio), created on first use, marked `isExcludedFromBackup = true` (it's a regenerable cache; iCloud backup of MP3s is waste). File naming: `{gistRecord.id.uuidString}.mp3`. API surface:
```swift
protocol AudioStoring {
    func writeAudio(_ data: Data, forGist id: UUID) throws -> (fileName: String, bytes: Int)
    func audioURL(forGist id: UUID) -> URL          // path; existence not guaranteed
    func audioExists(forGist id: UUID) -> Bool
    func deleteAudio(forGist id: UUID) throws
    func totalCacheBytes() -> Int
}
final class FileManagerService: AudioStoring { ... }
```
- Also implements the budget check `enforceBudget(records:nowPlayingID:)` described in §7. Pure `FileManager` + `Foundation`; fully unit-testable against a temp directory.
- Used by: `GistPipeline` (write), `PlayerEngine` (read/exists), pruning (delete).

**SwiftData store — new `GistRecord`, replaces template `Item`** — see §6.

**`GistPipeline` — new, `Gista/Gista/App/Services/GistPipeline.swift`**
- Does: the one production pipeline, both entry points:
  - `ingest(url: URL)` — creates a `GistRecord` (state `.queued`), then runs fetch-script → persist → voice → persist audio metadata.
  - `regenerateAudio(for: GistRecord)` — re-enters the same pipeline at the voicing stage using the persisted `scriptText`. Regeneration is a **normal path**: same states, same progress UI, same completion. There is no separate "re-download" code path.
- Structure: an `actor` (or `@MainActor` service with an internal FIFO `AsyncStream` worker — implementer's choice, but externally serial). One job at a time, FIFO; a second `ingest` while one is running queues behind it. Progress is written directly to the `GistRecord`'s `state` field, so every UI surface observes progress through SwiftData — the pipeline has no published state of its own.
- On completion: measures duration by instantiating `AVAudioPlayer` once over the written file (`player.duration`), stores `audioDuration`/`audioBytes`/`audioFileName`, sets state `.ready`, then triggers `FileManagerService.enforceBudget` (§7).
- Depends on: `WikipediaService`, `TTSProviding`, `AudioStoring`, `ModelContext`.
- Used by: `SharedContentService` (queue drain), `LibraryViewModel` (retry button), `PlayerEngine` (play-when-audio-missing → regenerate).

**`SharedContentService` — exists, trimmed**
- Keeps: app-group `UserDefaults` queue drain on launch + `didBecomeActive`, dedupe.
- Changes: the `url` branch now calls `GistPipeline.ingest(url:)` and removes the item from the queue. The `pdf` and `text` branches are removed from the drain loop (v1 is URLs only; the extension no longer enqueues them). No other behavior changes.

**Share extension — `ShareViewController` / `ShareViewControllerVM`, rewired**
- `ShareViewControllerVM` drops `userId` loading, sign-in checks, and `LinkSender` entirely. New job: extract the page URL from the extension context, validate it with the **same** URL-parsing rule as `WikipediaService` (the parsing function moves into the `Shared` framework so both targets use one implementation — `Shared/WikipediaURL.swift`), and:
  - Valid Wikipedia article URL → append `{type:"url", content: urlString, date: ...}` to the `ShareQueue` app-group array (mechanism already exists) → show "Added to Gista" → complete the extension request.
  - Anything else → show "Gista reads Wikipedia pages for now" inline in the extension UI and complete without enqueueing. Rejecting at share time is decided (v1): it's the cheapest possible feedback, and it means the main-app pipeline can treat a non-Wikipedia URL in the queue as a program error (log and drop), not a user-facing state.
- The extension performs **no network calls**. It stays iOS-only-UIKit as it is today.

**`PlayerEngine` — new, `Gista/Gista/App/Services/PlayerEngine.swift`**
- The single audio engine. `@MainActor final class PlayerEngine: ObservableObject`, one instance created in `GistaApp` and injected via `.environmentObject`. Owns:
  - An `AVAudioPlayer` over the local MP3. Decided: `AVAudioPlayer`, not `AVPlayer` — v1 plays complete local files only, no streaming, and `AVAudioPlayer` gives duration/rate/seek with the least machinery. If v3 segment streaming ever needs `AVPlayer`, that swap is internal to this one class.
  - Published state: `currentGistID: UUID?`, `isPlaying: Bool`, `currentTime: TimeInterval`, `duration: TimeInterval`, `rate: Float` (0.75/1.0/1.25/1.5/2.0). A 0.5 s timer updates `currentTime` while playing.
  - Commands: `play(gist:)`, `togglePlayPause()`, `seek(to:)`, `skip(by: ±15)`, `setRate(_:)`, `stop()`.
  - `AVAudioSession`: category `.playback` (activated on first play), so audio continues in background — requires adding `UIBackgroundModes = [audio]` to the app's `Info.plist` (currently absent).
  - Interruption handling (`AVAudioSession.interruptionNotification`): pause on `.began`; resume on `.ended` only when `shouldResume` option is set. Route change (`routeChangeNotification`, `.oldDeviceUnavailable` — headphones unplugged): pause. Positions live in memory; nothing is persisted mid-track (clips are ~2 minutes; persisted resume position is YAGNI — decided).
  - `MPNowPlayingInfoCenter` (title, elapsed, duration, rate, artwork placeholder) + `MPRemoteCommandCenter` (play, pause, toggle, skipForward/Backward 15 s, changePlaybackPosition). This is what makes lock screen, AirPods, and CarPlay work — it comes with the engine, not with the Live Activity.
  - Live Activity lifecycle (§8): start on `play` when app resigns active (or immediately on play — see §8), update on state change, end on `stop`/completion/app-terminate.
  - On `play(gist:)`: if `audioExists` → play. If not (evicted, or state is `.scriptReady`/`.failed(.voicing)`) → call `GistPipeline.regenerateAudio(for:)`, surface the pipeline state in the player UI ("Voicing…"), and auto-play on completion. One pipeline, two entry points, one player.
  - On natural completion: set `isPlayed = true`, increment `playCount`, set `lastPlayedAt`, clear Now Playing / end Live Activity.
- Depends on: `AVFoundation`, `MediaPlayer`, `AudioStoring`, `GistPipeline`, `ModelContext` (for play bookkeeping), `ActivityKit`.
- Used by: `PlaybackView`, `MiniPlalyerView` (both become dumb views over this object), remote commands, Live Activity intent.

**`LibraryViewModel` — fill in, `Gista/Gista/App/ViewModels/LibraryViewModel.swift`**
- `@MainActor final class LibraryViewModel: ObservableObject`. Fetches `[GistRecord]` sorted by `createdAt` descending (via `@Query` in the view or a fetch in the VM — decided: the VM owns fetching so `LibraryView` stays testable and so the VM can merge in pipeline/retry affordances). Exposes: the records, `delete(record:)` (deletes SwiftData row **and** its audio file — the one place script text dies), `retry(record:)` → `GistPipeline`, and per-record display state (status line text from §5's mapping, duration string, played badge).
- `LibraryView` rewire: drop the injected `articles:`/`gists:` arrays and the `Article`/`Gist` struct currency; rows render `GistRecord` directly. `Gist.previews` stops being reachable from production code (previews may keep it). Tab bar (decided): v1 trims the `TabView` to **Home** and **Settings**; `MyStudioView`, `MyResourcesView`, and `SearchView` are dormant — the tabs are removed from the `TabView` builder, files untouched.

**`PlaybackView` / `MiniPlalyerView` — rewired**
- Both drop their local `@State isPlaying/progress` and hardcoded article and bind to `PlayerEngine` + the current `GistRecord`. `MiniPlalyerView` shows nothing when `currentGistID == nil`, and keeps its existing tap-to-open-`PlaybackView` navigation via `NavigationManager` (which already has `.playback(articleId:)` — the associated value's meaning becomes the `GistRecord.id`; the enum case name is not worth renaming).

**`GistaApp` — rewired**
- Remove the `userCredentials.isAuthenticated` gate (and the duplicate gate inside `ContentView`): launch screen → `ContentView` unconditionally. Remove the `FirebaseService.shared.initialize()` call and the notification-permission request from `init()` (v1 sends no notifications; asking for permission at launch with no payoff is hostile). Firebase config files and `FirebaseService` remain in the repo, dormant. Add `.modelContainer(for: GistRecord.self)`, create `PlayerEngine`/`GistPipeline`/`FileManagerService` in a small composition root, inject via environment.

**`GistaWidgets` — new widget-extension target** — Live Activity only, §8.

---

## 5. The pipeline and its state machine

`GistRecord.state` is a `String`-backed enum persisted on the record; every surface renders from it.

```
                    ingest(url)
                        │
                     .queued
                        │  fetch lead extract (WikipediaService)
                 .fetchingScript ──────── failure ──→ .failed(stage:.script, reason)
                        │ script persisted                     │ retry → .fetchingScript
                  .scriptReady   ◀──────────────┐
                        │  TTS (TTSProviding)   │ audio evicted (pruning sets state back)
                  .synthesizing ── failure ──→ .failed(stage:.voicing, reason)
                        │ audio written                        │ retry / play → .synthesizing
                     .ready
```

```swift
enum GistState: Codable, Equatable {
    case queued, fetchingScript, scriptReady, synthesizing, ready
    case failed(stage: Stage, reason: FailureReason)   // stored as two string fields
    enum Stage: String, Codable { case script, voicing }
}
```

Key properties, stated explicitly:

- **`.scriptReady` is both a forward state and the eviction state.** Pruning a `.ready` gist's audio sets it back to `.scriptReady`. Playing or retrying a `.scriptReady` gist runs `.synthesizing → .ready`. Regeneration is therefore literally the same edges as first-time production — no special case.
- **`.failed(stage: .script)`** keeps the record (with `sourceURL`) so the user sees what they shared and can retry; nothing about it is voiced. **`.failed(stage: .voicing)`** keeps the script — retry never refetches Wikipedia.
- **Mapping onto the existing `GistStatus` concept** (reused, per the settled design): a computed bridge on `GistRecord` yields user-facing strings for any UI written against `productionStatus`:

| `GistState` | `inProduction` | `productionStatus` string |
|---|---|---|
| `.queued` | true | "Queued" |
| `.fetchingScript` | true | "Reading page" |
| `.scriptReady` | false | "Ready to voice" |
| `.synthesizing` | true | "Voicing" |
| `.ready` | false | "Ready" |
| `.failed` | false | "Needs retry" |

- **Both surfaces, one source:** in-app views observe the SwiftData record (status text + spinner on the row / in the player); the Live Activity is only ever started for a *playing* gist, so it renders `PlayerEngine` state, not pipeline state — with one exception: play-on-missing-audio shows "Voicing…" in-app only; the Live Activity is not started until audio actually plays. Decided: the Live Activity never displays production progress in v1.

## 6. SwiftData schema

One entity. No relationships in v1 — categories, segments, and users are all out of scope (see §14; `segments[]` returns in v3 as a child entity when chunking exists — designing it now would be speculation).

```swift
@Model
final class GistRecord {
    @Attribute(.unique) var id: UUID
    // Identity & source
    var title: String                // Wikipedia display title
    var sourceURL: String            // exactly what the user shared
    var wikipediaTitle: String       // normalized REST-API title, e.g. "Alan_Turing"
    var lang: String                 // "en", "fr", … from the shared URL's subdomain
    var thumbnailURLString: String?  // from the summary response, for the row/artwork
    var createdAt: Date
    // Script — the durable source of truth. Never evicted. Dies only with the record.
    var scriptText: String?          // nil only before .scriptReady is first reached
    var scriptSource: String         // "wikipedia_lead" (v2 adds "llm_script", …)
    // Audio — derived, evictable cache metadata
    var audioFileName: String?       // nil ⇔ no cached audio on disk
    var audioDuration: Double?       // seconds, measured after synthesis
    var audioBytes: Int?
    var voiceID: String?             // voice used for the cached audio ("21m00Tcm4TlvDq8ikWAM")
    var modelID: String?             // "eleven_flash_v2_5"
    // Pipeline state (GistState flattened for persistence)
    var stateRaw: String             // "queued" | "fetchingScript" | …
    var failureStage: String?        // "script" | "voicing"
    var failureReason: String?       // machine token, e.g. "offline", "quota", "disambiguation"
    // Playback bookkeeping
    var isPlayed: Bool               // set at ≥90% of duration or natural completion
    var playCount: Int
    var lastPlayedAt: Date?
}
```

- **Container:** `GistaApp` gets `.modelContainer(for: GistRecord.self)`. Store lives in the app container (default location); the share extension does **not** open the store — its only channel is the `ShareQueue` app-group defaults, which keeps SwiftData single-process and avoids container-sharing complexity entirely (decided).
- **`Item.swift`:** deleted — file removed from disk and from the `Gista` target. It has zero references besides itself. Clean slate, no migration: there is no existing user data anywhere (the library was sample structs), so the schema starts at version 1 with no legacy story.
- The `Gist`/`GistSegment`/`GistStatus`/`Article` structs in `Gista/Shared/Models/` stay compiled (the dormant backend layer and the `GistStatus` bridge use them) but are no longer the UI's currency.

## 7. Storage & pruning

**Budget:** 200 MB of audio cache (constant `AudioCacheBudget.maxBytes`). At `mp3_44100_128` (~1 MB/min) a lead-extract gist is ~2–3 MB, so the budget holds roughly 80–100 gists — far beyond v1 usage. No settings UI for it (YAGNI).

**What is never evicted:** `scriptText`, and the audio of the currently-playing gist. Script text is KB and permanent; it is deleted only by explicit user deletion of the gist.

**Eviction order:** candidates = records with `audioFileName != nil`, excluding `currentGistID`. Sort ascending by `lastPlayedAt ?? createdAt` (least-recently-touched first — recency is the signal; a separate play-count weighting adds nothing at this library size, decided). Evict until `totalCacheBytes() ≤ maxBytes`. Eviction = delete file + `audioFileName/audioDuration/audioBytes/voiceID/modelID = nil` + state `.ready → .scriptReady`, atomically per record.

**Foreground enforcement (primary):** `enforceBudget` runs (1) on app launch, (2) after every successful synthesis, (3) on `didBecomeActive`. This is the guarantee; it is cheap (one directory-size sum plus a fetch).

**Background enforcement (opportunistic):** a `BGProcessingTask` (identifier `Voqa.io.Gista.audioPrune`, registered at launch, `requiresExternalPower = false`, resubmitted after each run) runs the same `enforceBudget` plus an orphan sweep (files on disk with no matching record → delete; records claiming audio that isn't on disk → normalize to `.scriptReady`). `BGTaskScheduler` is best-effort and may not fire for days — it is explicitly a janitor, never the mechanism correctness depends on.

**Regeneration:** covered by the state machine — an evicted gist is `.scriptReady`; play or retry re-enters `.synthesizing` in the one pipeline. Cost of a regeneration is one ElevenLabs call over text we already have; this is the designed trade of "text is truth, audio is cache."

## 8. Live Activity (secondary surface)

New target `GistaWidgets` (WidgetKit extension, `NSSupportsLiveActivities = YES` in the **app's** Info.plist).

- `GistaPlaybackAttributes: ActivityAttributes` — fixed: `gistID: UUID`, `title: String`; `ContentState`: `isPlaying: Bool`, `elapsed: TimeInterval`, `duration: TimeInterval`, `stateDate: Date` (for `Text(timerInterval:)` auto-ticking progress without frequent updates).
- Lock-screen banner + Dynamic Island (compact: play/pause glyph; expanded: title, auto-ticking elapsed, play/pause button). Play/pause is a `Button(intent:)` with a `LiveActivityIntent` (`TogglePlaybackIntent`) whose `perform()` executes **in the app process** and calls `PlayerEngine.togglePlayPause()` — no second playback implementation, no IPC of audio state. Skip buttons: not in v1 (lock-screen Now Playing already provides them).
- Lifecycle, owned entirely by `PlayerEngine`: start when playback starts (decided: start immediately on play, not on background transition — simpler, and the Dynamic Island is useful even while the app is open); update on play/pause/seek; end (`.immediate` dismissal) on stop, natural completion, or when a different gist starts (end then start fresh).
- Deployment target is 18.0 (§3), so `Button(intent:)` and `LiveActivityIntent` are unconditionally available; no availability branches. If the user has Live Activities disabled, `Activity.request` throws, the engine logs and moves on — in-app player and Now Playing carry everything, which is why this surface is additive by construction.

## 9. Error handling

| Failure | Where caught | Record state | User experience |
|---|---|---|---|
| Non-Wikipedia URL shared | Share extension (`WikipediaURL` parse) | No record created | Inline in share sheet: "Gista reads Wikipedia pages for now." Extension completes without enqueueing. If one still appears in the queue (stale queue from an old build), pipeline logs and drops it. |
| Offline at script fetch | `WikipediaService` (URLError) | `.failed(.script, "offline")` | Row shows "Needs retry" + reason "You were offline"; Retry button. No auto-retry in v1 (decided — a background retry loop is complexity without evidence of need). |
| Wikipedia 404 / page missing | `WikipediaService` | `.failed(.script, "notFound")` | "Couldn't find that page." Retry available (page may exist later; cheap). |
| Disambiguation page (`type == "disambiguation"`) | `WikipediaService` | `.failed(.script, "disambiguation")` | "That's a disambiguation page — share a specific article." Retry hidden (retrying can't succeed); Delete offered. |
| Empty/missing `extract` | `WikipediaService` | `.failed(.script, "emptyExtract")` | "This page has no summary to read." Retry hidden; Delete offered. |
| ElevenLabs 401 / quota exhausted | `ElevenLabsTTSProvider` | `.failed(.voicing, "quota")` | "Voice service unavailable right now." Script retained; Retry re-enters `.synthesizing` only. |
| ElevenLabs 429 | Provider retries once (Retry-After or 2 s), then | `.failed(.voicing, "rateLimited")` | Same retry affordance. |
| ElevenLabs 5xx / network drop mid-TTS | Provider | `.failed(.voicing, "network")` | Same. Partial data is never written — `writeAudio` happens only with the complete response body. |
| Audio session interruption (call, Siri, other app) | `PlayerEngine` notifications | unchanged | Pause on `.began`; auto-resume on `.ended` iff `shouldResume`. Position kept in memory. |
| Headphones unplugged | `PlayerEngine` route change | unchanged | Pause (platform convention). |
| Audio pruned / missing at play time | `PlayerEngine.play` (`audioExists == false`) | `.scriptReady → .synthesizing` | Player shows "Voicing…" progress, auto-plays on completion. Identical to first-time production. |
| Pruned mid-playback | Cannot happen by construction | — | Eviction always excludes `currentGistID`, and both eviction paths run through the same `enforceBudget`. |
| Corrupt audio file (`AVAudioPlayer` init throws) | `PlayerEngine.play` | treat as evicted | Delete file, normalize record to `.scriptReady`, fall into the regeneration path. |
| App killed during `.fetchingScript`/`.synthesizing` | Launch-time sweep in `GistPipeline` | in-flight states → `.queued` / `.scriptReady` | Launch normalization: any record found in a transient state re-enters the queue at the appropriate stage. |

## 10. Testing strategy

**Unit tests (no simulator, no quota) — the bulk:**
- `WikipediaURL` parsing: desktop/mobile/language hosts, `/wiki/` and `index.php?title=`, fragments, percent-encoding, rejects (news sites, wikimedia.org, bare wikipedia.org home). Pure function in `Shared` — trivially exhaustive.
- `WikipediaService` against a stubbed `URLSession` (the codebase already has the `NetworkServiceProtocol` injection pattern): canned JSON fixtures for standard page, disambiguation (`type`), missing extract, 404, 5xx.
- `ElevenLabsTTSProvider` request construction (URL, headers, body, cap/truncation) and error mapping, against a stub transport. Never hits the network in tests.
- `GistPipeline` with `FixtureTTSProvider` + fixture Wikipedia stub + temp-dir `FileManagerService` + **in-memory `ModelContainer`** (`ModelConfiguration(isStoredInMemoryOnly: true)`): full state-machine walk — ingest happy path, each failure stage, retry from each failure, `regenerateAudio` from `.scriptReady`, launch normalization of transient states, FIFO ordering.
- `FileManagerService`: write/read/delete/size accounting; `enforceBudget` eviction order (LRU by `lastPlayedAt ?? createdAt`), now-playing exclusion, orphan sweep — against a temp directory with synthetic files.
- State-machine bridge: `GistState` ↔ `stateRaw`/`failure*` round-trip; `GistStatus` string mapping.

**Simulator / on-device (manual or UI-test):**
- Share-sheet flow (extension UI, queue handoff) — extension testing requires the simulator.
- Real playback, background audio, lock-screen controls, interruption behavior (trigger a simulated call), route change — on device; simulator audio-session behavior is not faithful.
- Live Activity render + intent button — device or simulator (iOS 18 sim supports Live Activities).
- `BGProcessingTask` — via the LLDB private trigger (`e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"Voqa.io.Gista.audioPrune"]`).

**Quota discipline:** exactly one component (`ElevenLabsTTSProvider`) can spend money, and it is selected only in the default composition root without `-UseFixtureTTS`. M1 validates real audio quality with a handful of real calls; every subsequent development day runs on the fixture. A single cached real MP3 checked into the test fixtures folder doubles as the listening-quality reference.

## 11. Auth de-gating

- `GistaApp`: launch screen → `ContentView`, no credential check; `ContentView`: remove its internal `isAuthenticated` branch and the `OnboardingView` fallback.
- Firebase is no longer initialized; the notification-permission prompt is removed (nothing in v1 notifies).
- Kept dormant, compiling, unreferenced from the v1 flow: `OnboardingView(+Model)`, `AppleSignInButton`, `LaunchScreen`'s onboarding wiring (launch screen itself stays), `FirebaseService`, `UserCredentials` (the type still exists; `ContentView`'s toolbar shows the app name instead of username), `UserProfile` (reachable from Settings is fine but not required — decided: the profile toolbar button is removed in v1; Settings keeps a plain "Account — coming back later" row or nothing).
- Rationale is settled: with a local library there is no `userId` in the core loop. When accounts return (sync, paid tiers), the dormant code is the starting point.

## 12. Firebase backend migration/removal plan

| Asset | Disposition |
|---|---|
| `LinkSender.swift` (extension) | **Deleted.** Its entire purpose was `POST /links/store`; the extension's new job (validate + enqueue) is already served by the existing app-group queue. `LinkError`/`LinkResponse` shrink to whatever the extension VM still throws/shows (keep `LinkError` cases used by URL validation; delete `LinkResponse`). |
| `GistaService.swift`, `GistaServiceProtocol`, request/response models (`CreateUserRequest`, `GistUpdateRequest`, `GistaServiceResponse`, `ArticleData`, `ArticlesResponse`…) | **Dormant.** Stay in the target, zero call sites from the v1 flow. The backend ambition is deferred, not deleted. |
| `GistaServiceViewModel`, `Views/Debug/GistaService*`, `ShareTestView`, `TestShareView` | Dormant; the `showTestView` sheet hook in `ContentView` is removed. |
| `FirebaseService`, GoogleService plist, Firebase SPM deps | Dormant; `initialize()` call removed (§11). Dependencies stay in the project (removing SPM packages is churn with no v1 payoff — decided). |
| `SharedContentService` | Kept — it is the ingestion transport (trimmed per §4.2). |
| `NetworkService` / `NetworkProtocols` | Kept — `WikipediaService` reuses the injection pattern; backend-specific endpoints go unused. |
| Repo-root stale `Shared/` and `GistaShare/` duplicate dirs | Not in the build; flagged for deletion as post-v1 housekeeping (not done as part of this spec's implementation to keep the diff reviewable). |
| Cloud Functions deployment (`us-central1-dof-ai`) | Untouched by the app. Decommissioning the deployment is an ops decision outside this spec. |

## 13. Milestones

Dependency-ordered; each answers one question. A milestone is done when its question has a demonstrated answer.

**M1 — The pleasantness spike. ✅ DONE 2026-07-25.** Executed as a standalone script (`scripts/gist_spike.py`), *not* an in-app debug view — no Xcode build was needed to answer the question, which made the milestone minutes long instead of days. Two articles synthesised: `Voyager 1` (613 chars → 56.3s) and `Murphy v. NCAA` (686 chars → 56.4s), both via **Daniel `onwK4e9ZLuTAKqWW03F9`** ("Steady Broadcaster"), `eleven_flash_v2_5`, `mp3_44100_128`.
*Question: is a Wikipedia lead extract actually pleasant to listen to?* **Answered yes, emphatically.** Founder's verdict: *"it was almost easier for me to start building this than to read the wiki. hells yes it was useful."* That sentence is the product thesis — reading Wikipedia is a chore avoided; listening to it is a thing actually done.

Corrections this milestone forced into the spec: Rachel `21m00Tcm4TlvDq8ikWAM` is **not in the account** (she is a library voice; free tier rejects her via API with 402) — Daniel is the v1 default. Voice choice moves from "constant" to "the one real aesthetic decision in v1". The Keychain → xcconfig → Info.plist path is **not yet validated** (the spike read Keychain directly), so that validation moves to the first milestone that builds Swift. Both MP3s are kept as §10 fixtures in `build/`.

**M2 — Local truth.** `GistRecord` + model container; delete `Item.swift`; `FileManagerService` (write/read/exists/delete/size); `GistPipeline` happy path + failure states behind `TTSProviding` (fixture-first); auth de-gated; `LibraryViewModel` + `LibraryView` rendering real records with live status; retry and delete.
*Question: does a URL become a persistent, replayable library row that survives relaunch?*

**M3 — The share sheet is the front door.** Extension rewire (validate → enqueue → confirm; `LinkSender` deleted); `SharedContentService` trim; queue drain → pipeline; non-Wikipedia rejection message.
*Question: does Safari → Share → open Gista → playable gist work with no debugger attached?*

**M4 — A real audio app.** `PlayerEngine` complete: audio session + background mode, interruptions, route change, rate control, skip/seek; `PlaybackView` and `MiniPlalyerView` rewired onto it; Now Playing + remote commands; play-bookkeeping (`isPlayed`, `playCount`, `lastPlayedAt`).
*Question: does playback behave like Overcast-class table stakes — lock screen, AirPods, calls?*

**M5 — Audio is a cache.** Budget + LRU eviction + now-playing exclusion; foreground triggers; `BGProcessingTask` janitor + orphan sweep; regeneration path exercised end-to-end (evict a gist, tap play, watch it re-voice and play).
*Question: can audio vanish at any time without the user ever hitting a dead end?*

**M6 — Leaves the app gracefully.** `GistaWidgets` target; Live Activity lock screen + Dynamic Island with `TogglePlaybackIntent`; error-state UI polish across every §9 row; full fixture-based test pass green.
*Question: is playback controllable from outside the app, and does every failure have a face and a next step?*

## 14. Non-goals for v1 (YAGNI, explicitly)

- No LLM summarization, no length modes, no Q&A, no chat-with-the-page — and per §15 this is a *direction* rejection, not a "later" deferral. Gista reads; it does not analyse.
- No chunking/segments in v1 — that is v2 (§15).
- No accounts, sync, sharing, publishing, ratings, follower counts (`isPublished`, `ratings`, `users` fields go dormant with the `Gist` struct).
- No non-Wikipedia sources (news, blogs, PDFs, pasted text). The extension says so plainly.
- No voice picker, no speed persistence per gist, no EQ, no sleep timer.
- No queue/up-next, no autoplay-next-gist, no playlists, no categories UI.
- No settings for storage budget, no cellular/Wi-Fi policy toggles (a TTS call is ~KB up / ~2 MB down).
- No push or local notifications; no "your gist is ready" banner (production takes seconds while the app is open).
- No download-ahead/prefetch; audio is made on demand and cached.
- No CarPlay app, no widgets beyond the Live Activity, no watchOS.
- No analytics/telemetry.
- No persisted resume position; no auto-retry loops.

## 15. The upgrade ladder (documented so v1 doesn't paint over it)

| Version | Script source | Cost per gist | What changes in this design |
|---|---|---|---|
| **v1** | Wikipedia lead extract (`page/summary`) — hand-written, already in summary register, ~250–400 words | 1 TTS call, **zero** summarization spend | This spec. |
| **v2** | Full article, chunked into segments, N TTS calls | N TTS calls | `segments` (the concept already present in the legacy `Gist.segments`/`GistSegment`) becomes a child entity of `GistRecord`; `PlayerEngine` gains a segment cursor (this is the moment `AVPlayer`/queue semantics may replace `AVAudioPlayer`, internal to the engine). |
| **v3** | Same sources, better listening: voice picker, playback speed, a queue of pages | no new per-gist cost | `PlayerEngine` gains rate/queue; `voiceID` becomes user-selectable on the record instead of a constant. |

**Founder's positioning constraint (2026-07-25), load-bearing:** *"this is not meant to be in-depth like NotebookLM — straightforward reading with all sorts of possibilities in the future."*

This sets the direction of the ladder, and it is the opposite of the obvious one. "Better Gista" means **more and better reading**, not more analysis. Concretely:

The ladder has **two independent axes**, and an LLM belongs on the second one — not the first:

| Axis | What "better" means | On the road | Off the road |
|---|---|---|---|
| **Coverage** | how much of the document you hear | lead extract → full article (chunked segments) | condensing, length modes |
| **Delivery** | how the document is told to you | persona-scripted readers, voice choice, speed | Q&A, chat-with-the-page, cross-source synthesis |

So an LLM **is** coming — for *delivery*, not comprehension. Founder's framing (2026-07-25): personas that add flavour, *"scripting like a comedian or a right wing conservative… just adding flavour depending on readers choice."* The facts stay straight; the telling gets personality. This is the same idea as the original 2026-07-24 brainstorm's *"different kind of readers with different kind of styles"* — it is the founding vision resurfacing, not new scope.

### The Reader concept

A **Reader = persona (script style) + voice (vocal delivery)**, chosen as one unit. v1 ships exactly one Reader: **"Straight"** — identity transform (the extract is voiced as fetched) with Daniel. Adding a Reader later must not require a migration, which is why persistence is shaped as **one source → many renditions** (§6): the same article read two ways is two renditions of one durable source. Audio cache identity is therefore `revisionID + readerID + voiceID`, not `revisionID` alone.

### Two classes of persona — different plumbing

Founder's example that forces this distinction: *"an adversarial reader, whose style is to read but have a ready and possibly counter fact for every claim… can help users read a document more than 1 way the first time."*

| Class | Example | Needs | Pipeline shape |
|---|---|---|---|
| **Style-only** | comedian, conservative, dramatic | nothing external | pure `sourceText → scriptText` transform, one LLM call |
| **Knowledge-adding** | adversarial, steelman, fact-check | facts not in the document | retrieval + grounding + citations *before* the transform |

Only the first is a simple text transform. **Do not design the script-source seam as text→text only**, or the knowledge-adding class won't fit it later.

**Hazard, recorded now so it isn't discovered late:** an adversarial reader that *fabricates* counter-facts is worse than no feature — it launders hallucination as scholarship, in audio, where the user cannot see a citation. If that Reader is ever built it requires grounded retrieval, verifiable sources, and framing that makes plain the user is hearing a *challenge* rather than an established fact. Not a v1 concern; a v1 *constraint on the seam*.

v1's "no LLM" therefore remains correct — not because an LLM is unwelcome, but because the first Reader is the honest one, and it needs no model at all.

The load-bearing seams that make the ladder cheap: `TTSProviding` (voice production is swappable), the script-source boundary inside `GistPipeline`, `scriptSource` on the record, and one `PlayerEngine` behind all surfaces.

## 16. Open questions (with recommendations)

1. **Output format `mp3_44100_128` vs `_192`?** Recommend 128 kbps: speech at flash v2.5 gains nothing audible at 192, and cache math stays at ~1 MB/min. Revisit only if M1 listening says otherwise.
2. **Should M1's spike view survive as a hidden debug tool?** Recommend yes, behind `#if DEBUG` — it is the cheapest way to audition future voices/models without touching the pipeline.
3. **Wikipedia languages beyond English at launch?** The design passes the URL's language through (§4.2) and the model is multilingual, so it works by construction. Recommend: leave it enabled, test English only, and don't advertise it.
4. **What does the extension do when the user shares from the Wikipedia *app* (which shares canonical `en.wikipedia.org/wiki/...` URLs) vs. Safari?** Both produce parseable URLs; recommend explicitly testing the Wikipedia app in M3 but building nothing special.
5. **Decommission the `dof-ai` Cloud Functions deployment now or later?** Outside the app's scope; recommend leaving it running untouched until v1 ships (nothing calls it), then reviewing hosting cost separately.
6. **Bundle-ID / App Group availability for the new `GistaWidgets` target** (needs the same team + `NSSupportsLiveActivities`; no app group needed since the intent runs in-process). Recommend confirming the provisioning profile situation at the start of M6, not before.
7. **Keep the launch screen's dark-mode-forced styling?** Cosmetic; recommend keeping `preferredColorScheme(.dark)` as-is for v1 and not opening a theming discussion.

---

*Implementation note: this spec deliberately touches no Swift source. The first code change is M1's spike.*
