//
//  AudioOrphanSweep.swift
//  Gista
//
//  Created by Tony Nlemadim on 7/25/26.
//

import Foundation

/// A minimal, caller-supplied claim: "this rendition believes its audio lives at this filename."
/// Mirrors the shape of whatever the persistence layer stores (e.g. a future rendition record's
/// `audioFileName: String?`), without depending on that type.
struct AudioRecordReference: Sendable, Equatable {
    let renditionID: UUID
    /// `nil` means the rendition currently has no audio on disk by its own bookkeeping (e.g. it was
    /// already evicted, or never synthesized). Such records are excluded from both directions of
    /// the sweep — they aren't claiming a file, so they can't be found missing one.
    let audioFileName: String?

    init(renditionID: UUID, audioFileName: String?) {
        self.renditionID = renditionID
        self.audioFileName = audioFileName
    }
}

/// Findings from comparing disk contents against known renditions. Deliberately a *report*, not an
/// action — see the rationale on `AudioOrphanSweep.diff(diskFiles:knownRecords:)`.
struct AudioOrphanSweepResult: Sendable, Equatable {
    /// Files present on disk that no known rendition references. Deletion candidates.
    let orphanedFiles: [StoredAudioFile]
    /// Renditions whose claimed `audioFileName` is not on disk — audio vanished by some path other
    /// than this app's own eviction (manual deletion, a restore from backup that dropped the
    /// excluded-from-backup directory, a partially-completed write that got interrupted, etc).
    /// The caller should normalize these records back to "script ready" / clear their audio metadata.
    let recordsMissingAudio: [UUID]
}

/// Orphan sweep is a pure comparison — no disk access here (that happens once, in
/// `FileManagerService.listAudioFiles()`, and the result is handed in). No SwiftData access either;
/// the caller supplies both sides as plain value types.
///
/// Decision: **report, don't delete.** Both directions of mismatch can plausibly be transient rather
/// than a genuine leak or a genuine loss:
///   - A file can be on disk moments after `writeAudio` returns but before the owning record's
///     write to persistence has committed — that file would look orphaned if swept in that instant.
///   - A record can be mid-way through `regenerateAudio` (old `audioFileName` cleared, new file not
///     written yet) and transiently look like it's missing audio it never actually lost.
/// A pure, disk-and-SwiftData-free function has no way to rule out either race, and this module is
/// intentionally kept ignorant of pipeline/in-flight state so it stays simple and independently
/// testable. Silently deleting a file this function *thinks* is orphaned is the one mistake in this
/// whole cache design that would be irreversible and invisible to the user (the audio is gone, no
/// error surfaced anywhere). The caller — expected to be the janitor task described in spec §7,
/// which already knows what's in flight — is far better positioned to safely act on these findings,
/// e.g. by re-running the sweep at the next scheduled interval and only acting on ids that show up
/// as orphaned/missing twice in a row, or by simply cross-checking against the pipeline's current job.
enum AudioOrphanSweep {
    static func diff(
        diskFiles: [StoredAudioFile],
        knownRecords: [AudioRecordReference]
    ) -> AudioOrphanSweepResult {
        let claimedFileNames = Set(knownRecords.compactMap(\.audioFileName))
        let orphanedFiles = diskFiles.filter { !claimedFileNames.contains($0.fileName) }

        let diskFileNames = Set(diskFiles.map(\.fileName))
        let recordsMissingAudio = knownRecords.compactMap { record -> UUID? in
            guard let fileName = record.audioFileName else { return nil }
            return diskFileNames.contains(fileName) ? nil : record.renditionID
        }

        return AudioOrphanSweepResult(orphanedFiles: orphanedFiles, recordsMissingAudio: recordsMissingAudio)
    }
}
