//
//  ElevenLabsTTSProvider.swift
//  Gista
//
//  Real `TTSProviding` implementation. Ported from `scripts/gist_spike.py`'s
//  `synthesize()` — a WORKING, PROVEN call against the live API (M1 spike, 2026-07-25).
//  See docs/superpowers/specs/2026-07-25-gista-v1-elevenlabs-readout-design.md §4.2, §9.
//

import Foundation

// MARK: - API key seam

/// Where `ElevenLabsTTSProvider` gets its API key from. Deliberately a tiny
/// protocol, not a concrete Keychain/xcconfig reader — see
/// `InfoPlistElevenLabsAPIKeyProvider` doc comment for exactly what is and isn't
/// wired today.
public protocol ElevenLabsAPIKeyProviding: Sendable {
    func apiKey() -> String?
}

/// Reads the key from `Bundle.main`'s Info.plist under `ElevenLabsAPIKey`.
///
/// **NOT YET WIRED.** The intended pipeline, per spec §4.2 and LESSONS.md
/// (2026-07-25), is:
///   macOS login Keychain (`elevenlabs-api-key`)
///     → `scripts/generate-secrets.sh` (Run Script build phase, not created)
///     → `Config/Secrets.xcconfig` (gitignored, not generated)
///     → attached to the `Gista` target's build configurations (project.pbxproj)
///     → `INFOPLIST_KEY_ElevenLabsAPIKey = $(ELEVENLABS_API_KEY)` (project.pbxproj)
///     → this reader.
///
/// None of the xcconfig/Info.plist/build-setting steps exist yet — this agent's
/// scope explicitly excludes editing `project.pbxproj`, and there is currently no
/// `Info.plist` file in the `Gista` target at all (`GENERATE_INFOPLIST_FILE = YES`
/// with no on-disk override; confirmed by inspection 2026-07-25). Until that
/// wiring lands, `Bundle.main.object(forInfoDictionaryKey:)` will always return
/// `nil` here and `synthesize` will throw `TTSError.missingAPIKey`.
///
/// The M1 spike (`scripts/gist_spike.py`) reads the Keychain item directly via
/// `security find-generic-password`, which is a fine pattern for a one-off Python
/// script but is explicitly NOT what production Swift code should do (spec §4.2:
/// "do NOT read Keychain directly from the provider").
public struct InfoPlistElevenLabsAPIKeyProvider: ElevenLabsAPIKeyProviding, Sendable {
    private let infoDictionaryKey: String
    private let bundle: Bundle

    public init(infoDictionaryKey: String = "ElevenLabsAPIKey", bundle: Bundle = .main) {
        self.infoDictionaryKey = infoDictionaryKey
        self.bundle = bundle
    }

    public func apiKey() -> String? {
        guard let key = bundle.object(forInfoDictionaryKey: infoDictionaryKey) as? String,
              !key.isEmpty else {
            return nil
        }
        return key
    }
}

// MARK: - Provider

/// `POST https://api.elevenlabs.io/v1/text-to-speech/{voiceID}?output_format=mp3_44100_128`,
/// key in `xi-api-key`, JSON body `{ text, model_id, voice_settings }` — the exact
/// call `scripts/gist_spike.py`'s `synthesize()` makes, verified working live 2026-07-25.
///
/// `actor`, not a `final class`: the only mutable-looking thing here is none —
/// all stored properties are `let` — but making it an actor (rather than a
/// `Sendable`-conforming struct) sidesteps a strict-concurrency wrinkle: the
/// stored `session: URLSessionProtocol` existential isn't itself `Sendable`
/// (that protocol lives in `NetworkProtocols.swift`, outside this agent's scope
/// to change), and actor isolation doesn't require stored-property types to be
/// `Sendable` the way a `Sendable` struct/class would.
public actor ElevenLabsTTSProvider: TTSProviding {
    /// Verified working against the live API 2026-07-25 (M1 spike). Do NOT default
    /// to Rachel (`21m00Tcm4TlvDq8ikWAM`) — she is a library voice not available to
    /// this account and 402s (LESSONS.md).
    public enum Defaults {
        public static let voiceID = "onwK4e9ZLuTAKqWW03F9" // Daniel, "Steady Broadcaster"
        public static let modelID = "eleven_flash_v2_5"
    }

    /// Our own cap, not ElevenLabs'. A lead extract (~250-400 words, ~1500-2500
    /// chars) never gets close to this.
    ///
    /// Billing note: `eleven_flash_v2_5` bills at **0.5 credits per character**,
    /// so a 613-char script (the M1 "Voyager 1" spike run) costs ~306 credits.
    /// This cap therefore bounds worst-case spend per call to ~2500 credits.
    public static let maxTextChars = 5000

    private let session: URLSessionProtocol
    private let apiKeyProvider: any ElevenLabsAPIKeyProviding
    private let baseURL: URL

    public init(
        session: URLSessionProtocol = URLSession.shared,
        apiKeyProvider: any ElevenLabsAPIKeyProviding = InfoPlistElevenLabsAPIKeyProvider(),
        baseURL: URL = URL(string: "https://api.elevenlabs.io/v1")!
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
        self.baseURL = baseURL
    }

    public func synthesize(
        text: String,
        voiceID: String = Defaults.voiceID,
        modelID: String = Defaults.modelID
    ) async throws -> TTSResult {
        guard let apiKey = apiKeyProvider.apiKey(), !apiKey.isEmpty else {
            throw TTSError.missingAPIKey
        }

        let clipped = Self.truncated(text, limit: Self.maxTextChars)

        guard let requestURL = Self.synthesisURL(baseURL: baseURL, voiceID: voiceID) else {
            throw TTSError.invalidResponse
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            text: clipped,
            model_id: modelID,
            voice_settings: .init(stability: 0.5, similarity_boost: 0.75)
        )
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw TTSError.transport("Failed to encode request body: \(error.localizedDescription)")
        }

        return try await perform(
            request,
            voiceID: voiceID,
            modelID: modelID,
            characterCount: clipped.count,
            allowRetryOn429: true
        )
    }

    // MARK: - Networking

    private func perform(
        _ request: URLRequest,
        voiceID: String,
        modelID: String,
        characterCount: Int,
        allowRetryOn429: Bool
    ) async throws -> TTSResult {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TTSError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw TTSError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            // Partial data is never written as success — this branch only runs
            // once `session.data(for:)` has returned a complete response body.
            return TTSResult(audio: data, voiceID: voiceID, modelID: modelID, characterCount: characterCount)

        case 401:
            throw TTSError.unauthorized(message: Self.errorMessage(from: data))

        case 402:
            throw TTSError.paymentRequired(message: Self.errorMessage(from: data))

        case 429:
            if allowRetryOn429 {
                let delay = Self.retryAfterSeconds(from: http) ?? 2.0
                try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
                return try await perform(
                    request,
                    voiceID: voiceID,
                    modelID: modelID,
                    characterCount: characterCount,
                    allowRetryOn429: false
                )
            }
            throw TTSError.rateLimited(retryAfter: Self.retryAfterSeconds(from: http))

        case 400...499:
            throw TTSError.badRequest(statusCode: http.statusCode, message: Self.errorMessage(from: data))

        case 500...599:
            throw TTSError.serverError(statusCode: http.statusCode)

        default:
            throw TTSError.invalidResponse
        }
    }

    // MARK: - Request shape

    private struct RequestBody: Encodable {
        let text: String
        let model_id: String
        let voice_settings: VoiceSettings

        struct VoiceSettings: Encodable {
            let stability: Double
            let similarity_boost: Double
        }
    }

    private static func synthesisURL(baseURL: URL, voiceID: String) -> URL? {
        let endpoint = baseURL
            .appendingPathComponent("text-to-speech")
            .appendingPathComponent(voiceID)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "output_format", value: "mp3_44100_128")]
        return components.url
    }

    /// ElevenLabs error bodies are shaped `{"detail": {"status": "...", "message": "..."}}`
    /// (seen in the M1 spike's 402 response). Falls back to a top-level `message`
    /// field, then to raw text, then nil.
    private static func errorMessage(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = object["detail"] as? [String: Any], let message = detail["message"] as? String {
                return message
            }
            if let detail = object["detail"] as? String {
                return detail
            }
            if let message = object["message"] as? String {
                return message
            }
        }
        return String(data: data.prefix(500), encoding: .utf8)
    }

    private static func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(value)
    }

    // MARK: - Text cap

    /// Truncates at the last sentence boundary (`.`, `!`, `?`) at or before
    /// `limit`, rather than erroring — spec §4.2: "a lead extract will never hit
    /// this in practice," so this path exists for safety, not for the common case.
    private static func truncated(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let prefix = String(text.prefix(limit))
        if let boundary = lastSentenceBoundary(in: prefix) {
            return String(prefix[..<boundary])
        }
        return prefix
    }

    private static func lastSentenceBoundary(in text: String) -> String.Index? {
        let terminators: Set<Character> = [".", "!", "?"]
        var lastIndex: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            if terminators.contains(text[index]) {
                lastIndex = text.index(after: index)
            }
            index = text.index(after: index)
        }
        return lastIndex
    }
}
