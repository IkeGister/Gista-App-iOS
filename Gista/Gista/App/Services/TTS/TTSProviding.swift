//
//  TTSProviding.swift
//  Gista
//
//  The seam that makes voice production swappable (device-direct ElevenLabs today,
//  a server proxy later, a canned fixture in tests) without touching call sites.
//  See docs/superpowers/specs/2026-07-25-gista-v1-elevenlabs-readout-design.md §4.2, §9, §15.
//

import Foundation

// MARK: - Result

/// Encoded audio plus the metadata a caller needs to persist alongside it
/// (`GistRecord.audioBytes`/`voiceID`/`modelID` per spec §6).
public struct TTSResult: Equatable, Sendable {
    public let audio: Data
    public let voiceID: String
    public let modelID: String
    /// Character count actually sent to the provider (after any cap/truncation),
    /// not the caller's original input length.
    public let characterCount: Int

    public init(audio: Data, voiceID: String, modelID: String, characterCount: Int) {
        self.audio = audio
        self.voiceID = voiceID
        self.modelID = modelID
        self.characterCount = characterCount
    }
}

// MARK: - Typed errors

/// Real failure cases we've actually hit against ElevenLabs (see .planning/LESSONS.md,
/// 2026-07-25 entries) plus the generic buckets every HTTP TTS provider needs.
/// Spec §9 rows are noted per case; a fixture-backed provider can throw any of these
/// on demand so UI/pipeline error handling is testable without spending quota.
public enum TTSError: Error, Equatable, Sendable {
    /// No API key available from the configured `ElevenLabsAPIKeyProviding` source.
    /// Not a spec §9 row on its own — this is a local configuration failure that
    /// precedes any network call; callers should treat it like `.unauthorized`.
    case missingAPIKey

    /// HTTP 401. In this account this means the API key's scope is missing
    /// `user_read`/`voices_read` — see LESSONS.md — but any 401 (bad/rotated key
    /// too) lands here. Spec §9 row: "ElevenLabs 401 / quota exhausted" →
    /// `.failed(.voicing, "quota")` → "Voice service unavailable right now."
    case unauthorized(message: String?)

    /// HTTP 402. ElevenLabs' actual shape for "can't use this voice/plan
    /// combination" (e.g. a free-tier account requesting a library voice — see
    /// LESSONS.md: Rachel `21m00Tcm4TlvDq8ikWAM` 402s on this account). Spec §9
    /// row: same "ElevenLabs 401 / quota exhausted" row — the spec's table
    /// doesn't split 401 vs 402, but this provider keeps them as distinct typed
    /// cases per the more detailed real-response-shape mapping asked for in this
    /// unit's brief, since 401 and 402 have different real remediations (rotate
    /// key vs upgrade plan / change voice).
    case paymentRequired(message: String?)

    /// HTTP 429, after this provider's one built-in retry (Retry-After header,
    /// or 2s default) has already been attempted and also failed. Spec §9 row:
    /// "ElevenLabs 429" → `.failed(.voicing, "rateLimited")`.
    case rateLimited(retryAfter: TimeInterval?)

    /// Any other 4xx. No dedicated §9 row; surfaced the same as `.serverOrNetwork`
    /// in practice (spec's simplified table folds all non-401/429 failures into
    /// "ElevenLabs 5xx / network drop mid-TTS" → `.failed(.voicing, "network")`).
    case badRequest(statusCode: Int, message: String?)

    /// HTTP 5xx. Spec §9 row: "ElevenLabs 5xx / network drop mid-TTS" →
    /// `.failed(.voicing, "network")`.
    case serverError(statusCode: Int)

    /// Transport-level failure: offline, timeout, connection dropped mid-response,
    /// request encoding failure. Spec §9 row: same "network" row as `.serverError`.
    /// Partial data is never surfaced as success — see `ElevenLabsTTSProvider`,
    /// which only returns a `TTSResult` on a complete 2xx response body.
    case transport(String)

    /// 2xx response whose body wasn't usable (shouldn't happen for this endpoint,
    /// which returns raw audio bytes on success — defensive only).
    case invalidResponse
}

// MARK: - Protocol

/// Async, minimal, and honest: takes script text plus which voice/model to use,
/// returns encoded audio and the metadata needed to persist it. One call per gist
/// in v1 (spec §4.2) — no streaming, no partial results.
public protocol TTSProviding: Sendable {
    /// - Parameters:
    ///   - text: script text to voice. Implementations are free to enforce their
    ///     own length policy (e.g. `ElevenLabsTTSProvider`'s 5000-char cap).
    ///   - voiceID: provider-specific voice identifier.
    ///   - modelID: provider-specific model identifier.
    func synthesize(text: String, voiceID: String, modelID: String) async throws -> TTSResult
}
