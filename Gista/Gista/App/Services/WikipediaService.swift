//
//  WikipediaService.swift
//  Gista
//
//  Turns a shared Wikipedia URL (or bare article title) into script text.
//
//  Ported from `scripts/gist_spike.py` (`parse_article`, `fetch_lead_extract`), the
//  proven M1 spike that validated this exact network call against the live API.
//  See docs/superpowers/specs/2026-07-25-gista-v1-elevenlabs-readout-design.md §4.2, §9.
//

import Foundation

// MARK: - Parsed reference

/// The result of resolving user input (a shared URL or a bare title) down to
/// what the Wikipedia REST API needs: a title and a language.
public struct WikipediaArticleReference: Equatable, Sendable {
    /// Decoded, human-readable title with underscores replaced by spaces
    /// (e.g. "Alan Turing", not "Alan_Turing").
    public let title: String
    /// Language subdomain, e.g. "en", "fr". Passed through as-is — v1 does not
    /// translate or restrict language (spec §4.2, "Language handling (decided)").
    public let lang: String

    public init(title: String, lang: String) {
        self.title = title
        self.lang = lang
    }
}

// MARK: - Typed errors

/// Distinct, switchable failure cases. Each maps to a §9 row in the design spec
/// so the UI can show exact user-facing copy per case rather than a generic message.
public enum WikipediaServiceError: Error, Equatable, Sendable {
    /// Host is not `*.wikipedia.org` (or bare `wikipedia.org`). Spec §9 row:
    /// "Non-Wikipedia URL shared" — in practice this is caught at share-extension
    /// time using the same parsing rule; this case exists so `WikipediaService`
    /// enforces the identical rule if a bad URL ever reaches the pipeline anyway.
    case notAWikipediaURL
    /// Host is a Wikipedia host but the path isn't `/wiki/<title>` or
    /// `/w/index.php?title=<title>` (e.g. the bare portal, a diff link, a
    /// non-article special page). No direct §9 row (spec's URL-shape rule lives
    /// in the parsing description, §4.2); treated the same as `notAWikipediaURL`
    /// by any caller that doesn't need to distinguish them.
    case unrecognizedURLShape
    /// REST API returned 404. Spec §9 row: "Wikipedia 404 / page missing" →
    /// `.failed(.script, "notFound")` → "Couldn't find that page."
    case pageNotFound
    /// Response `type == "disambiguation"`. Spec §9 row: "Disambiguation page" →
    /// `.failed(.script, "disambiguation")` → "That's a disambiguation page —
    /// share a specific article." Retry hidden; delete offered.
    case disambiguationPage
    /// `extract` is missing or blank after trimming. Spec §9 row: "Empty/missing
    /// extract" → `.failed(.script, "emptyExtract")` → "This page has no summary
    /// to read." Retry hidden; delete offered.
    case emptyExtract
    /// Transport-level failure — no connection, timeout, DNS failure, or any
    /// other `URLSession` error. Spec §9 row: "Offline at script fetch" →
    /// `.failed(.script, "offline")` → "You were offline"; retry available, no
    /// auto-retry (decided).
    case offline
    /// REST API returned 5xx. No dedicated §9 row for Wikipedia 5xx specifically;
    /// treat the same as `.offline` for user-facing purposes (transient, retry).
    case serverError(statusCode: Int)
    /// Response was 2xx but didn't decode into the expected summary shape.
    /// Defensive catch-all, not in §9 — Wikipedia's REST API is stable, but a
    /// malformed/unexpected body shouldn't crash the pipeline.
    case invalidResponse
}

// MARK: - URL / title parsing

/// Pure parsing, no network. Mirrors `parse_article()` from `scripts/gist_spike.py`,
/// extended to also accept `/w/index.php?title=` and mobile (`{lang}.m.wikipedia.org`)
/// hosts per spec §4.2's fuller URL-shape rule.
///
/// Note: spec §4.2 says this parser should eventually live in the `Shared` framework
/// so the share extension and the app use one implementation. That move is NOT done
/// here — this agent's scope is limited to `WikipediaService.swift` in the `Gista` app
/// target (see report). The share extension currently has its own, separate
/// URL-validation code and does not call this type.
public enum WikipediaURL {
    /// - Parameters:
    ///   - input: either a bare article title ("Alan Turing", "Alan_Turing") or a
    ///     full URL (`https://en.wikipedia.org/wiki/Alan_Turing`,
    ///     `https://en.m.wikipedia.org/wiki/Alan_Turing`,
    ///     `https://en.wikipedia.org/w/index.php?title=Alan_Turing`).
    ///   - defaultLang: language to use when `input` is a bare title (which has no
    ///     subdomain to read a language from). Ignored when `input` is a URL — the
    ///     URL's own subdomain always wins.
    public static func parse(_ input: String, defaultLang: String = "en") throws -> WikipediaArticleReference {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        let lowered = trimmed.lowercased()
        guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://") else {
            // Bare title: no host to validate, no language to extract.
            guard !trimmed.isEmpty else { throw WikipediaServiceError.unrecognizedURLShape }
            return WikipediaArticleReference(
                title: trimmed.replacingOccurrences(of: "_", with: " "),
                lang: defaultLang
            )
        }

        guard let components = URLComponents(string: trimmed), let host = components.host, !host.isEmpty else {
            throw WikipediaServiceError.unrecognizedURLShape
        }

        let lowerHost = host.lowercased()
        guard lowerHost == "wikipedia.org" || lowerHost.hasSuffix(".wikipedia.org") else {
            throw WikipediaServiceError.notAWikipediaURL
        }
        // The bare portal host has no subdomain-derived language and no article path.
        guard lowerHost != "wikipedia.org" else {
            throw WikipediaServiceError.unrecognizedURLShape
        }

        // Language is the leading subdomain label. This naturally normalizes the
        // mobile host `{lang}.m.wikipedia.org` to `{lang}` since we only read the
        // first label, ignoring any `m` label in between.
        guard let langLabel = lowerHost.split(separator: ".").first, !langLabel.isEmpty else {
            throw WikipediaServiceError.unrecognizedURLShape
        }
        let lang = String(langLabel)

        let pathComponents = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        let rawTitle: String
        if pathComponents.first == "wiki", pathComponents.count >= 2 {
            rawTitle = pathComponents[1...].joined(separator: "/")
        } else if pathComponents == ["w", "index.php"],
                  let titleValue = components.queryItems?.first(where: { $0.name == "title" })?.value,
                  !titleValue.isEmpty {
            rawTitle = titleValue
        } else {
            throw WikipediaServiceError.unrecognizedURLShape
        }

        guard !rawTitle.isEmpty else { throw WikipediaServiceError.unrecognizedURLShape }

        let decodedTitle = rawTitle.removingPercentEncoding ?? rawTitle
        let title = decodedTitle.replacingOccurrences(of: "_", with: " ")
        return WikipediaArticleReference(title: title, lang: lang)
    }
}

// MARK: - Summary result

/// What the pipeline needs out of a Wikipedia lead-extract fetch.
public struct WikipediaSummary: Equatable, Sendable {
    /// Wikipedia's own display title (may differ slightly from the requested title,
    /// e.g. capitalization or redirect resolution).
    public let title: String
    public let description: String?
    /// The script. Hand-written lead extract, plain text (no HTML/wikitext).
    public let extract: String
    public let revision: Int?
    /// Canonical desktop article URL from `content_urls.desktop.page`, if present.
    public let pageURL: URL?
    public let thumbnailURL: URL?
    public let lang: String
}

// MARK: - Service

/// Fetches `GET https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}`.
///
/// Stateless apart from its injected collaborators, so this is an `actor` rather
/// than a class with locking or a `Sendable`-constrained struct: an `actor` doesn't
/// require its stored `URLSessionProtocol` existential to itself be `Sendable`
/// (actor state is protected by isolation, not by copy-safety), which keeps this
/// type strict-concurrency-clean without needing changes to the shared
/// `URLSessionProtocol` definition in `NetworkProtocols.swift` (not this agent's file).
public actor WikipediaService {
    /// Wikimedia requires an explicit, identifying User-Agent — the default
    /// URLSession / curl / Python UA gets a 403. See LESSONS.md (2026-07-25).
    public static let defaultUserAgent = "Gista/1.0 (iOS)"

    private let session: URLSessionProtocol
    private let userAgent: String

    public init(session: URLSessionProtocol = URLSession.shared, userAgent: String = WikipediaService.defaultUserAgent) {
        self.session = session
        self.userAgent = userAgent
    }

    /// Convenience entry point: parses `input` (URL or bare title) and fetches its summary.
    public func fetchSummary(for input: String, defaultLang: String = "en") async throws -> WikipediaSummary {
        let reference = try WikipediaURL.parse(input, defaultLang: defaultLang)
        return try await fetchSummary(title: reference.title, lang: reference.lang)
    }

    /// Fetches the lead-extract summary for an already-resolved title + language.
    public func fetchSummary(title: String, lang: String) async throws -> WikipediaSummary {
        guard let url = Self.summaryURL(title: title, lang: lang) else {
            throw WikipediaServiceError.unrecognizedURLShape
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Any transport-level failure (offline, timeout, DNS, TLS, cancelled)
            // buckets to `.offline` — the pipeline's story for all of these is
            // identical: "you were offline, retry when able."
            throw WikipediaServiceError.offline
        }

        guard let http = response as? HTTPURLResponse else {
            throw WikipediaServiceError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            break
        case 404:
            throw WikipediaServiceError.pageNotFound
        case 500...599:
            throw WikipediaServiceError.serverError(statusCode: http.statusCode)
        default:
            throw WikipediaServiceError.invalidResponse
        }

        let decoded: SummaryResponse
        do {
            decoded = try JSONDecoder().decode(SummaryResponse.self, from: data)
        } catch {
            throw WikipediaServiceError.invalidResponse
        }

        if decoded.type == "disambiguation" {
            throw WikipediaServiceError.disambiguationPage
        }

        let extract = (decoded.extract ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extract.isEmpty else {
            throw WikipediaServiceError.emptyExtract
        }

        let canonicalURL = decoded.content_urls?.desktop?.page.flatMap(URL.init(string:))
        let thumbnailURL = decoded.thumbnail?.source.flatMap(URL.init(string:))
        let revision = decoded.revision.flatMap(Int.init)

        return WikipediaSummary(
            title: decoded.title ?? title,
            description: decoded.description,
            extract: extract,
            revision: revision,
            pageURL: canonicalURL,
            thumbnailURL: thumbnailURL,
            lang: lang
        )
    }

    private static func summaryURL(title: String, lang: String) -> URL? {
        let underscored = title.replacingOccurrences(of: " ", with: "_")
        guard let encodedTitle = underscored.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "https://\(lang).wikipedia.org/api/rest_v1/page/summary/\(encodedTitle)")
    }
}

// MARK: - Wire model

/// Minimal decode target for `page/summary` — only the fields v1 uses.
private struct SummaryResponse: Decodable {
    let type: String?
    let title: String?
    let description: String?
    let extract: String?
    /// Wikipedia's REST API returns this as a numeric string (e.g. "1234567890").
    let revision: String?
    let content_urls: ContentURLs?
    let thumbnail: Thumbnail?

    struct ContentURLs: Decodable {
        let desktop: PageLink?
    }
    struct PageLink: Decodable {
        let page: String?
    }
    struct Thumbnail: Decodable {
        let source: String?
    }
}
