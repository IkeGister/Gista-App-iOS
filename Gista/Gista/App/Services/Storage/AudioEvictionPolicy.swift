//
//  AudioEvictionPolicy.swift
//  Gista
//
//  Created by Tony Nlemadim on 7/25/26.
//

import Foundation

/// The storage budget for the audio cache. Spec §7: 200 MB, which at `mp3_44100_128` (~1 MB/min)
/// holds roughly 80–100 lead-extract-length gists — far beyond v1 usage.
enum AudioCacheBudget {
    static let maxBytes = 200 * 1024 * 1024
}

/// A candidate audio file the eviction policy may choose to delete. One per rendition (not per
/// source article — a single article can have several renditions, e.g. different persona readers,
/// each with its own audio file and its own eviction eligibility).
///
/// This type carries no disk state and no SwiftData dependency — it's a plain, caller-constructed
/// snapshot. The caller (a future janitor/pipeline component) is responsible for building this list
/// from whatever persistence layer it owns.
struct AudioEvictionCandidate: Sendable, Equatable {
    /// The rendition's id — matches the `UUID` used to key `AudioStoring`.
    let id: UUID
    let sizeBytes: Int
    /// When this rendition was last played, if ever.
    let lastPlayedAt: Date?
    /// Fallback recency signal when a rendition has never been played.
    let createdAt: Date
    /// True if this rendition's audio is actively playing right now. Never evicted, regardless of
    /// how stale `lastPlayedAt`/`createdAt` are.
    let isPlaying: Bool

    init(id: UUID, sizeBytes: Int, lastPlayedAt: Date?, createdAt: Date, isPlaying: Bool) {
        self.id = id
        self.sizeBytes = sizeBytes
        self.lastPlayedAt = lastPlayedAt
        self.createdAt = createdAt
        self.isPlaying = isPlaying
    }

    /// The LRU sort key: last played, or creation time if never played. Matches spec §7 exactly:
    /// "Sort ascending by `lastPlayedAt ?? createdAt` (least-recently-touched first)."
    fileprivate var recencyKey: Date { lastPlayedAt ?? createdAt }
}

/// Pure decision function for what audio to evict to stay under budget. No disk access, no
/// SwiftData, no I/O of any kind — fully unit-testable by constructing `AudioEvictionCandidate`
/// values directly. The caller is responsible for:
///   1. Building the candidate list (only renditions that currently have cached audio).
///   2. Marking `isPlaying` correctly for whichever rendition is on-screen/audible right now.
///   3. Actually deleting the returned ids' files (via `AudioStoring`) and updating persistence
///      (clearing `audioFileName`/`audioBytes`/etc., flipping state back to "script ready").
enum AudioEvictionPolicy {

    /// Returns the ids to evict, in eviction order (most disposable first), so that the remaining
    /// total is at or under `budgetBytes`. Returns an empty array if already under budget, or if the
    /// currently-playing rendition alone exceeds budget (it is never evicted no matter what).
    static func candidatesToEvict(
        from candidates: [AudioEvictionCandidate],
        budgetBytes: Int = AudioCacheBudget.maxBytes
    ) -> [UUID] {
        let currentTotal = candidates.reduce(0) { $0 + $1.sizeBytes }
        guard currentTotal > budgetBytes else { return [] }

        let evictionOrder = candidates
            .filter { !$0.isPlaying }
            .sorted { lhs, rhs in
                if lhs.recencyKey != rhs.recencyKey { return lhs.recencyKey < rhs.recencyKey }
                // Deterministic tie-break so the function is a pure, stable ordering even when two
                // candidates share an exact timestamp (e.g. batch-imported records).
                return lhs.id.uuidString < rhs.id.uuidString
            }

        var runningTotal = currentTotal
        var toEvict: [UUID] = []
        for candidate in evictionOrder {
            guard runningTotal > budgetBytes else { break }
            toEvict.append(candidate.id)
            runningTotal -= candidate.sizeBytes
        }
        return toEvict
    }
}
