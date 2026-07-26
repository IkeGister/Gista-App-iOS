//
//  FileManagerService.swift
//  Gista
//
//  Created by Tony Nlemadim on 1/2/25.
//

import Foundation

// MARK: - Value types

/// Result of a successful audio write: the relative filename that was written (safe to persist,
/// e.g. as `GistRecord.audioFileName`) and its size in bytes.
struct AudioWriteResult: Sendable, Equatable {
    let fileName: String
    let bytes: Int
}

/// A single audio file as observed on disk, independent of any owning record.
/// `renditionID` is parsed back out of the filename when it matches our naming convention;
/// it is `nil` for any file that doesn't (a foreign/unexpected file — orphan sweep still reports it).
struct StoredAudioFile: Sendable, Equatable {
    let fileName: String
    let renditionID: UUID?
    let bytes: Int
}

// MARK: - Protocol

/// Owns the on-disk audio cache. Every operation is keyed by an opaque, caller-supplied `UUID`
/// ("rendition ID") — this type has no opinion about what that UUID identifies. In the v1 model it
/// may be a gist's own id; per the product direction toward multiple readings of one source
/// (persona renditions — comedian, adversarial reader, etc.), a single source article can have many
/// audio files on disk at once, one per rendition. The caller decides what's unique (e.g. a
/// composite of revisionID + readerID + voiceID) and mints a stable UUID for it; this store never
/// derives filenames from article titles or any other human-readable/business-meaning text, so
/// hostile titles (`Murphy v. National Collegiate Athletic Association` — dots, spaces, periods)
/// never reach the filesystem.
protocol AudioStoring: Sendable {
    /// Writes audio data for the given rendition, returning the relative filename that was written.
    /// Overwrites any existing file for the same id (used by regeneration).
    @discardableResult
    func writeAudio(_ data: Data, forRenditionID id: UUID) async throws -> AudioWriteResult

    /// Resolves any relative filename (as previously returned by `writeAudio`, or as persisted on a
    /// record) to an absolute file URL. Path is computed; existence is not guaranteed or checked.
    func url(forRelativeFileName fileName: String) async -> URL

    /// Convenience over `url(forRelativeFileName:)` using the deterministic filename for a rendition id.
    func audioURL(forRenditionID id: UUID) async -> URL

    func fileExists(relativeFileName fileName: String) async -> Bool
    func audioExists(forRenditionID id: UUID) async -> Bool

    /// Idempotent: deleting a file that is already gone is not an error.
    func deleteFile(relativeFileName fileName: String) async throws
    func deleteAudio(forRenditionID id: UUID) async throws

    /// Byte size of a single file, or `nil` if it doesn't exist / size can't be read.
    func fileSizeBytes(relativeFileName fileName: String) async -> Int?

    /// Sum of all audio file sizes currently in the cache directory.
    func totalDirectoryBytes() async -> Int

    /// Every audio file currently on disk. Used by orphan-sweep comparisons and `totalDirectoryBytes()`.
    func listAudioFiles() async -> [StoredAudioFile]
}

// MARK: - FileManagerService

/// Disk-backed implementation of `AudioStoring`. An `actor` so all file I/O happens off the main
/// actor and is serialized against itself; callers `await` every call.
///
/// Directory: `Application Support/Audio/` inside the **app container** (not the app group — the
/// share extension never touches audio, and Application Support is the correct home for a
/// regenerable, non-user-visible cache — Documents is for user-owned files and is exposed in the
/// Files app / iTunes file sharing, Caches can be purged by the OS at any time with no notice which
/// would fight the deliberate LRU eviction policy this app implements itself). The directory is
/// marked `isExcludedFromBackup = true` on creation: it's a cache, regenerable from `scriptText` via
/// TTS, and backing up megabytes of MP3 to iCloud is pure waste.
actor FileManagerService: AudioStoring {

    enum StoreError: Error, Sendable, Equatable, LocalizedError {
        case directoryUnavailable(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .directoryUnavailable(let reason): return "Audio cache directory unavailable: \(reason)"
            case .writeFailed(let reason): return "Failed to write audio file: \(reason)"
            }
        }
    }

    /// Absolute path to the audio cache directory. Exposed for callers that need to reason about it
    /// (e.g. logging, diagnostics); not part of the `AudioStoring` protocol surface.
    let directoryURL: URL

    /// Default initializer: resolves (and creates, if needed) `Application Support/Audio/` in the
    /// app container, and marks it excluded from backup.
    init() throws {
        let appSupport: URL
        do {
            appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw StoreError.directoryUnavailable(error.localizedDescription)
        }
        let audioDirectory = appSupport.appendingPathComponent("Audio", isDirectory: true)
        try Self.prepareDirectory(audioDirectory)
        self.directoryURL = audioDirectory
    }

    /// Test/advanced initializer: point the store at an arbitrary directory (e.g. a temp directory
    /// created per-test). Created and backup-excluded the same way as the default directory.
    init(directoryURL: URL) throws {
        try Self.prepareDirectory(directoryURL)
        self.directoryURL = directoryURL
    }

    private static func prepareDirectory(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw StoreError.directoryUnavailable(error.localizedDescription)
            }
        }
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(resourceValues) // best-effort; never block cache use on this
    }

    /// Deterministic, filesystem-safe filename for a rendition id. UUIDs are already safe (hex
    /// digits and dashes only), so no sanitization step is needed — this is precisely what makes
    /// hostile source titles a non-issue: titles never participate in filename derivation at all.
    private static func fileName(forRenditionID id: UUID) -> String {
        "\(id.uuidString).mp3"
    }

    // MARK: AudioStoring

    @discardableResult
    func writeAudio(_ data: Data, forRenditionID id: UUID) throws -> AudioWriteResult {
        let fileName = Self.fileName(forRenditionID: id)
        let fileURL = directoryURL.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw StoreError.writeFailed(error.localizedDescription)
        }
        return AudioWriteResult(fileName: fileName, bytes: data.count)
    }

    func url(forRelativeFileName fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    func audioURL(forRenditionID id: UUID) -> URL {
        url(forRelativeFileName: Self.fileName(forRenditionID: id))
    }

    func fileExists(relativeFileName fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forRelativeFileName: fileName).path)
    }

    func audioExists(forRenditionID id: UUID) -> Bool {
        fileExists(relativeFileName: Self.fileName(forRenditionID: id))
    }

    func deleteFile(relativeFileName fileName: String) throws {
        let fileURL = url(forRelativeFileName: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return } // idempotent
        try FileManager.default.removeItem(at: fileURL)
    }

    func deleteAudio(forRenditionID id: UUID) throws {
        try deleteFile(relativeFileName: Self.fileName(forRenditionID: id))
    }

    func fileSizeBytes(relativeFileName fileName: String) -> Int? {
        let fileURL = url(forRelativeFileName: fileName)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else {
            return nil
        }
        return attributes[.size] as? Int
    }

    func totalDirectoryBytes() -> Int {
        listAudioFiles().reduce(0) { $0 + $1.bytes }
    }

    func listAudioFiles() -> [StoredAudioFile] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directoryURL.path) else {
            return []
        }
        return names.compactMap { name -> StoredAudioFile? in
            guard name.hasSuffix(".mp3") else { return nil }
            let bytes = fileSizeBytes(relativeFileName: name) ?? 0
            let idString = String(name.dropLast(".mp3".count))
            return StoredAudioFile(fileName: name, renditionID: UUID(uuidString: idString), bytes: bytes)
        }
    }
}
