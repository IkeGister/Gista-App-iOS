//
//  GistRecord.swift
//  Gista
//
//  SwiftData schema for the v1 ElevenLabs readout pivot (spec: docs/
//  superpowers/specs/2026-07-25-gista-v1-elevenlabs-readout-design.md,
//  §5–§6), revised 2026-07-25 for the "one source, many renditions"
//  product direction: the same article can be read multiple ways by
//  different Readers (persona + voice together). v1 always creates exactly
//  one rendition per source, reader "straight"; no v1 UI exposes multiple
//  renditions — but the relationship exists so v2 adds a Reader without a
//  store migration.
//
//  Two entities:
//    GistSource    — durable, one per article. The permanent, never-evicted
//                    truth (URL, title, revision, fetched source text).
//    GistRendition — one-to-many from source. What actually gets voiced and
//                    played: reader identity, the voiced script, the audio
//                    cache metadata, job state, play bookkeeping.
//
//  Governing principle: text is the durable source of truth; audio is a
//  derived, evictable cache. Every audio-related field is optional metadata
//  that can be cleared without losing the rendition. Audio cache identity is
//  keyed on (revision, readerID, voiceID) — the same article read two ways
//  is two distinct audio artifacts.
//
//  These types live in the app target only. The share extension never opens
//  the SwiftData store — its sole channel is the ShareQueue app-group
//  defaults (spec §6, decided). `@Model` classes are not Sendable; do not
//  pass instances across actor boundaries — pass `id` (UUID) instead.
//

import Foundation
import SwiftData

// MARK: - Pipeline state (spec §5)

/// The production state machine, per rendition. Flattened for persistence
/// into `stateRaw` + `failureStage` + `failureReason` on `GistRendition`.
///
/// `.scriptReady` is both a forward state and the eviction state: pruning a
/// `.ready` rendition's audio sets it back to `.scriptReady`, and play/retry
/// from there re-enters `.synthesizing`. Regeneration is the same edges as
/// first-time production — no special case.
enum GistState: Codable, Equatable, Sendable {
    case queued
    case fetchingScript
    case scriptReady
    case synthesizing
    case ready
    /// `reason` is a machine token (e.g. "offline", "notFound",
    /// "disambiguation", "emptyExtract", "quota", "rateLimited", "network")
    /// mapped to user-facing copy at the UI layer (spec §9).
    case failed(stage: Stage, reason: String)

    enum Stage: String, Codable, Sendable {
        case script
        case voicing
    }

    /// Raw string persisted in `GistRendition.stateRaw`.
    var rawStateString: String {
        switch self {
        case .queued: return "queued"
        case .fetchingScript: return "fetchingScript"
        case .scriptReady: return "scriptReady"
        case .synthesizing: return "synthesizing"
        case .ready: return "ready"
        case .failed: return "failed"
        }
    }
}

// MARK: - Reader

/// A Reader is a persona and a voice **together** — a script style paired
/// with a vocal delivery. Represented as a stable string identifier on the
/// rendition. v1 ships exactly one: "straight" (identity transform of the
/// source text, voiced by the default voice). Future readers are style
/// transforms (comedian, …) or knowledge-adding readers (adversarial /
/// counter-fact) — the identifier space deliberately forecloses neither.
enum Reader {
    /// The v1 reader: script == source text, default voice.
    static let straight = "straight"
}

// MARK: - GistSource (durable, one per article)

/// The permanent record of a shared article. Never evicted; deleted only by
/// explicit user deletion, which cascades to its renditions. Cache-valid
/// until the Wikipedia revision id changes.
@Model
final class GistSource {
    @Attribute(.unique) var id: UUID

    // MARK: Identity
    /// Wikipedia display title — library row and Now Playing.
    var title: String
    /// Exactly what the user shared — kept verbatim for display and retry.
    var sourceURL: String
    /// Normalized REST-API title (e.g. "Alan_Turing") so a retry or refetch
    /// never has to re-parse `sourceURL`.
    var wikipediaTitle: String
    /// Language subdomain of the shared URL ("en", "fr", …); passed through
    /// to the summary endpoint and voiced by the same multilingual model.
    var lang: String
    /// Wikipedia revision id (`revision` in the REST summary response) —
    /// the cache-validity key for the fetched text: `sourceText` is the lead
    /// extract of exactly this revision, so staleness is a revid comparison,
    /// not a text diff. Nil until the first successful fetch.
    var wikipediaRevisionID: Int?
    /// From the summary response; row artwork / Now Playing placeholder.
    var thumbnailURLString: String?

    // MARK: Text — the durable truth. Never evicted.
    /// The raw fetched lead extract. Nil only before the first successful
    /// fetch. Dies only with the source (user deletion).
    var sourceText: String?
    /// Character count of `sourceText` — chars are the TTS cost unit
    /// (ElevenLabs bills per character; the provider enforces a 5,000-char
    /// cap), persisted so cost/size is knowable without loading the text.
    /// 0 until text is persisted.
    var sourceCharCount: Int
    /// Word count of `sourceText` — drives estimated-duration display before
    /// audio exists (eleven_flash_v2_5 measures ~117 wpm, see
    /// .planning/LESSONS.md). 0 until text is persisted.
    var sourceWordCount: Int

    // MARK: Dates
    /// Library sort key (descending).
    var createdAt: Date
    /// Bumped when the fetched text/revision is (re)persisted.
    var updatedAt: Date

    // MARK: Relationship
    /// Deleting a source takes its renditions (and their cached audio
    /// metadata) with it. Deleting a rendition never touches the source.
    @Relationship(deleteRule: .cascade, inverse: \GistRendition.source)
    var renditions: [GistRendition]

    init(
        id: UUID = UUID(),
        title: String = "",
        sourceURL: String,
        wikipediaTitle: String = "",
        lang: String = "en",
        wikipediaRevisionID: Int? = nil,
        thumbnailURLString: String? = nil,
        sourceText: String? = nil,
        sourceCharCount: Int = 0,
        sourceWordCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        renditions: [GistRendition] = []
    ) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
        self.wikipediaTitle = wikipediaTitle
        self.lang = lang
        self.wikipediaRevisionID = wikipediaRevisionID
        self.thumbnailURLString = thumbnailURLString
        self.sourceText = sourceText
        self.sourceCharCount = sourceCharCount
        self.sourceWordCount = sourceWordCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.renditions = renditions
    }
}

// MARK: - GistRendition (one reading of a source)

/// One reading of a source by one Reader: the script that was (or will be)
/// voiced, the evictable audio-cache metadata, the pipeline job state, and
/// per-rendition play bookkeeping. v1 creates exactly one per source
/// (`Reader.straight`).
@Model
final class GistRendition {
    @Attribute(.unique) var id: UUID

    /// The Reader (persona + voice pairing) this rendition belongs to.
    /// Stable identifier; v1 ships only `Reader.straight`. Part of the audio
    /// cache identity key (revision, readerID, voiceID).
    var readerID: String

    // MARK: Script — durable per rendition. Never evicted.
    /// The text actually voiced. For the "straight" reader this equals the
    /// source's `sourceText`; styled readers persist their transform here so
    /// regeneration never re-runs the transform. Nil before the script stage
    /// completes. Dies only with the rendition.
    var scriptText: String?
    /// The source revision `scriptText` was derived from — snapshot, not a
    /// pointer to the parent's (mutable) field. Lets staleness and the audio
    /// cache key be computed from the rendition alone even after the source
    /// is refetched at a newer revision. Nil before the script exists.
    var sourceRevisionID: Int?

    // MARK: Audio — derived, evictable cache metadata
    /// Relative filename inside the audio cache directory. Nil ⇔ no cached
    /// audio on disk. Relative, not absolute: the app container path changes
    /// between installs/updates. Naming convention is owned by
    /// FileManagerService (keyed on revision + reader + voice).
    var audioFileName: String?
    /// Seconds, measured after synthesis (AVAudioPlayer.duration).
    var audioDuration: Double?
    /// Byte size of the cached MP3; summed by cache-budget enforcement.
    var audioBytes: Int?
    /// Voice that produced the cached audio. Part of the cache identity key:
    /// the same script in a different voice is a different artifact.
    var voiceID: String?
    /// TTS model that produced the cached audio (e.g. "eleven_flash_v2_5").
    var modelID: String?

    // MARK: Pipeline state (GistState flattened for persistence)
    var stateRaw: String
    /// "script" | "voicing" — only when `stateRaw == "failed"`.
    var failureStage: String?
    /// Machine token, e.g. "offline", "quota", "disambiguation" — only when
    /// `stateRaw == "failed"`. UI maps tokens to copy per spec §9.
    var failureReason: String?

    // MARK: Playback bookkeeping (per rendition — two readings of one
    // article are listened to independently)
    /// Set at ≥90% of duration or natural completion; played badge.
    var isPlayed: Bool
    var playCount: Int
    /// Recency signal for LRU eviction (`lastPlayedAt ?? createdAt`).
    var lastPlayedAt: Date?

    // MARK: Dates
    /// Eviction fallback for never-played renditions.
    var createdAt: Date
    /// Bumped on every state transition.
    var updatedAt: Date

    // MARK: Relationship
    /// Inverse of `GistSource.renditions`. Optional as SwiftData requires
    /// for a to-one inverse; nil only transiently before insertion completes.
    var source: GistSource?

    init(
        id: UUID = UUID(),
        readerID: String = Reader.straight,
        scriptText: String? = nil,
        sourceRevisionID: Int? = nil,
        audioFileName: String? = nil,
        audioDuration: Double? = nil,
        audioBytes: Int? = nil,
        voiceID: String? = nil,
        modelID: String? = nil,
        state: GistState = .queued,
        isPlayed: Bool = false,
        playCount: Int = 0,
        lastPlayedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        source: GistSource? = nil
    ) {
        self.id = id
        self.readerID = readerID
        self.scriptText = scriptText
        self.sourceRevisionID = sourceRevisionID
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
        self.audioBytes = audioBytes
        self.voiceID = voiceID
        self.modelID = modelID
        self.stateRaw = state.rawStateString
        if case let .failed(stage, reason) = state {
            self.failureStage = stage.rawValue
            self.failureReason = reason
        } else {
            self.failureStage = nil
            self.failureReason = nil
        }
        self.isPlayed = isPlayed
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source
    }
}

// MARK: - State bridge

extension GistRendition {
    /// Typed view over the flattened persistence fields.
    ///
    /// Setting this also clears/sets the failure fields consistently and
    /// bumps `updatedAt` — always transition state through this property,
    /// never by writing `stateRaw` directly.
    var state: GistState {
        get {
            switch stateRaw {
            case "queued": return .queued
            case "fetchingScript": return .fetchingScript
            case "scriptReady": return .scriptReady
            case "synthesizing": return .synthesizing
            case "ready": return .ready
            case "failed":
                let stage = failureStage.flatMap(GistState.Stage.init(rawValue:)) ?? .script
                return .failed(stage: stage, reason: failureReason ?? "unknown")
            default:
                // Unknown raw value (future schema drift): safest floor is
                // .queued — the launch-time sweep re-enters the pipeline.
                return .queued
            }
        }
        set {
            stateRaw = newValue.rawStateString
            if case let .failed(stage, reason) = newValue {
                failureStage = stage.rawValue
                failureReason = reason
            } else {
                failureStage = nil
                failureReason = nil
            }
            updatedAt = Date()
        }
    }
}

// MARK: - GistStatus bridge (spec §5 mapping table)

extension GistRendition {
    /// True while the pipeline is actively working on this rendition.
    var inProduction: Bool {
        switch state {
        case .queued, .fetchingScript, .synthesizing: return true
        case .scriptReady, .ready, .failed: return false
        }
    }

    /// User-facing production status string for any UI written against the
    /// existing `GistStatus.productionStatus` concept.
    var productionStatus: String {
        switch state {
        case .queued: return "Queued"
        case .fetchingScript: return "Reading page"
        case .scriptReady: return "Ready to voice"
        case .synthesizing: return "Voicing"
        case .ready: return "Ready"
        case .failed: return "Needs retry"
        }
    }
}
