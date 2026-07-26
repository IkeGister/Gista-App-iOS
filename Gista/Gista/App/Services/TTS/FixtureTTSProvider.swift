//
//  FixtureTTSProvider.swift
//  Gista
//
//  Canned `TTSProviding` double. Used by all unit tests and, in the app, behind the
//  `-UseFixtureTTS` launch argument — this is what lets every development day after
//  M1 avoid burning ElevenLabs quota (spec §10, "Quota discipline").
//

import Foundation

public struct FixtureTTSProvider: TTSProviding, Sendable {
    /// What `synthesize` should do when called.
    public enum Outcome: Sendable, Equatable {
        case success
        case failure(TTSError)
    }

    private let audioData: Data
    private let delay: TimeInterval
    private let outcome: Outcome
    private let characterCountOverride: Int?

    /// - Parameters:
    ///   - audioData: bytes returned on `.success`. Defaults to a small synthetic
    ///     (not real-audio) placeholder — see "Fixture decision" in this agent's
    ///     report re: why a real M1 spike MP3 (`build/voyager-1.mp3`) is NOT loaded
    ///     here by default.
    ///   - delay: simulated network latency in seconds, so `.synthesizing` progress
    ///     UI is testable (spec §5's state machine spends real time in this state).
    ///     Pass `0` for instant tests.
    ///   - outcome: `.success`, or a specific `TTSError` to throw — lets callers
    ///     exercise every ElevenLabs failure row in §9 without touching the network.
    ///   - characterCountOverride: if nil, `TTSResult.characterCount` reports the
    ///     input text's length, mirroring the real provider's behavior of reporting
    ///     what was actually sent.
    public init(
        audioData: Data = FixtureTTSProvider.placeholderAudio,
        delay: TimeInterval = 1.0,
        outcome: Outcome = .success,
        characterCountOverride: Int? = nil
    ) {
        self.audioData = audioData
        self.delay = delay
        self.outcome = outcome
        self.characterCountOverride = characterCountOverride
    }

    public func synthesize(text: String, voiceID: String, modelID: String) async throws -> TTSResult {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        switch outcome {
        case .success:
            return TTSResult(
                audio: audioData,
                voiceID: voiceID,
                modelID: modelID,
                characterCount: characterCountOverride ?? text.count
            )
        case .failure(let error):
            throw error
        }
    }

    // MARK: - Fixtures

    /// A minimal, non-empty placeholder. This is NOT decodable/playable audio —
    /// it exists so `writeAudio`/size-accounting code paths have real bytes to
    /// work with. For audible fixture data (e.g. to sanity-check `PlayerEngine`
    /// against a real MP3), load one of the M1 spike files from `build/` via
    /// ``loadAudio(fromFilePath:)`` — see this agent's report for why that isn't
    /// wired in automatically.
    public static let placeholderAudio = Data([0xFF, 0xFB, 0x90, 0x00])

    /// Reads raw bytes from an arbitrary file path (e.g. a local, gitignored
    /// `build/voyager-1.mp3` during manual/dev testing). Returns nil if unreadable.
    /// Not used by default — `build/` is gitignored, so nothing under it is
    /// guaranteed to exist in CI or on a teammate's checkout.
    public static func loadAudio(fromFilePath path: String) -> Data? {
        FileManager.default.contents(atPath: path)
    }

    // MARK: - Launch-argument selection

    /// Whether the current process was launched with `-UseFixtureTTS`. The
    /// composition root (spec §4.2: "`GistaApp` — rewired... create
    /// `PlayerEngine`/`GistPipeline`/`FileManagerService` in a small composition
    /// root") is where this should actually be consulted to choose between
    /// `FixtureTTSProvider` and `ElevenLabsTTSProvider`; exposed here as a small
    /// utility so that wiring is a one-line check rather than a re-derivation of
    /// the launch-argument name.
    public static var isSelectedByLaunchArgument: Bool {
        ProcessInfo.processInfo.arguments.contains("-UseFixtureTTS")
    }
}

// MARK: - Convenience failure factories

public extension FixtureTTSProvider.Outcome {
    static var unauthorized: FixtureTTSProvider.Outcome { .failure(.unauthorized(message: "missing_permissions")) }
    static var paymentRequired: FixtureTTSProvider.Outcome { .failure(.paymentRequired(message: "paid_plan_required")) }
    static var rateLimited: FixtureTTSProvider.Outcome { .failure(.rateLimited(retryAfter: 2)) }
    static var serverError: FixtureTTSProvider.Outcome { .failure(.serverError(statusCode: 500)) }
    static var transportFailure: FixtureTTSProvider.Outcome { .failure(.transport("simulated network drop")) }
}
