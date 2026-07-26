//
//  PlayerEngine.swift
//  Gista
//
//  Created by Tony Nlemadim on 7/25/26.
//
//  THE single playback engine (spec §4.2). Every surface — PlaybackView,
//  MiniPlalyerView, lock screen / AirPods / CarPlay (via NowPlayingController),
//  and the Live Activity — is a view onto this one object. There is exactly
//  one of these, created in the app's composition root and injected via
//  `.environmentObject`. Do not create a second playback implementation.
//
//  Design decisions, per spec:
//    - `AVAudioPlayer` internally: v1 plays one complete local MP3, no
//      streaming. The player is `private`; if v2's segment queue needs
//      `AVPlayer`, that swap happens inside this class with no surface change.
//    - Missing audio is a NORMAL path, not an error (spec §5/§7): audio is an
//      evictable cache. Pressing play on a gist whose file is gone puts the
//      engine into `.preparing` and calls `regenerationHandler`, which
//      re-enters the pipeline; on success playback starts automatically.
//    - Playback bookkeeping (isPlayed/playCount/lastPlayedAt) and the Live
//      Activity lifecycle are driven by `onEvent` — the engine does not import
//      SwiftData or ActivityKit, so it does not race sibling work on
//      GistRecord. The M4 rewire wave connects those.
//
//  Concurrency: the class is @MainActor. Every off-main-actor callback
//  (AVAudioPlayerDelegate, AVAudioSession notifications, remote commands)
//  is hopped explicitly — see PlayerDelegateProxy below and the two
//  controllers. No @unchecked Sendable anywhere.
//

import Foundation
import AVFoundation
import MediaPlayer

// MARK: - Value types

/// The engine's currency for "a thing that can be played". Deliberately a
/// small value type rather than the SwiftData `GistRecord` (which is being
/// authored concurrently): integration adapts a record into this.
struct PlayableGist: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    /// Where the cached MP3 should live. `nil` (or a path that no longer
    /// exists) means the audio has been evicted or never synthesized —
    /// a normal state that routes through regeneration.
    let audioFileURL: URL?
    /// Persisted duration if known (GistRecord.audioDuration). Used only for
    /// display before the real file is loaded; the player's own duration wins.
    let expectedDuration: TimeInterval?

    init(id: UUID, title: String, audioFileURL: URL?, expectedDuration: TimeInterval? = nil) {
        self.id = id
        self.title = title
        self.audioFileURL = audioFileURL
        self.expectedDuration = expectedDuration
    }
}

/// Engine lifecycle events. The M4 rewire wave subscribes to drive SwiftData
/// bookkeeping (spec §4.2 "play-bookkeeping") and the Live Activity (spec §8).
enum PlaybackEvent: Equatable, Sendable {
    case didStartPlaying(gistID: UUID)
    case didPause(gistID: UUID)
    /// Fired at most once per load, at ≥90% of duration or natural completion.
    /// Maps to `GistRecord.isPlayed` (spec §6).
    case didReachPlayedThreshold(gistID: UUID)
    /// Natural end of the audio. Maps to playCount/lastPlayedAt + Now Playing
    /// teardown + Live Activity end.
    case didFinish(gistID: UUID)
    case didStop(gistID: UUID)
    /// Regeneration was needed but failed (or no handler is wired yet). The
    /// pipeline has already recorded the failure on the record; this exists so
    /// the player UI can fall out of "Voicing…".
    case regenerationFailed(gistID: UUID, message: String)
}

enum PlayerState: Equatable, Sendable {
    case idle
    /// Audio absent — the pipeline is re-voicing the script (spec: shows
    /// "Voicing…" in-app; the Live Activity is NOT started in this state).
    case preparing
    case playing
    case paused
}

// MARK: - Engine

@MainActor
final class PlayerEngine: ObservableObject {

    // MARK: Published state (the one source of truth for every surface)

    @Published private(set) var currentGist: PlayableGist?
    @Published private(set) var state: PlayerState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var rate: Float = 1.0

    var currentGistID: UUID? { currentGist?.id }
    var isPlaying: Bool { state == .playing }
    var isPreparing: Bool { state == .preparing }
    var progress: Double { duration > 0 ? min(max(currentTime / duration, 0), 1) : 0 }

    nonisolated static let availableRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    nonisolated static let skipInterval: TimeInterval = 15

    // MARK: Seams

    /// The regeneration seam (spec §5/§7). Wired to
    /// `GistPipeline.regenerateAudio(for:)` in the composition root: the
    /// handler re-enters the pipeline at `.synthesizing` using the persisted
    /// script and returns the URL of the freshly written MP3. The engine
    /// treats absent audio as a normal state — never as an error.
    var regenerationHandler: (@MainActor (PlayableGist) async throws -> URL)?

    /// Lifecycle events for bookkeeping / Live Activity. Invoked on the main actor.
    var onEvent: ((PlaybackEvent) -> Void)?

    // MARK: Internals

    private var player: AVAudioPlayer?
    private var delegateProxy: PlayerDelegateProxy?
    private let session: AudioSessionController
    private let nowPlaying: NowPlayingController
    private var progressTask: Task<Void, Never>?
    private var regenerationTask: Task<Void, Never>?
    private var wasPlayingBeforeInterruption = false
    private var hasFiredPlayedThreshold = false

    /// Defaults are constructed in the body (not as default arguments) because
    /// default-argument expressions evaluate in a nonisolated context and both
    /// controllers are @MainActor.
    init(
        session: AudioSessionController? = nil,
        nowPlaying: NowPlayingController? = nil
    ) {
        let session = session ?? AudioSessionController()
        let nowPlaying = nowPlaying ?? NowPlayingController(skipInterval: Self.skipInterval)
        self.session = session
        self.nowPlaying = nowPlaying

        session.onEvent = { [weak self] event in
            self?.handleSessionEvent(event)
        }
        nowPlaying.onCommand = { [weak self] command in
            self?.handleRemoteCommand(command)
        }
        nowPlaying.setUp()
    }

    // MARK: - Commands

    /// Loads a gist without starting playback. If audio is present the player
    /// is prepared paused; if absent the gist is current but idle (playback
    /// via `play()` will route through regeneration).
    func load(_ gist: PlayableGist) {
        activate(gist, autoplay: false)
    }

    /// Plays a gist. If its audio is on disk → plays. If not (evicted or never
    /// voiced) → `.preparing` + regeneration, then auto-plays (spec §4.2).
    func play(_ gist: PlayableGist) {
        activate(gist, autoplay: true)
    }

    /// Resumes the current gist (or starts regeneration if its audio is gone).
    func play() {
        guard let gist = currentGist else { return }
        if let player {
            startPlayback(player)
        } else if state != .preparing {
            activate(gist, autoplay: true)
        }
    }

    func pause() {
        guard state == .playing, let player else { return }
        player.pause()
        stopProgressUpdates()
        currentTime = player.currentTime
        state = .paused
        pushNowPlaying()
        if let id = currentGist?.id {
            emit(.didPause(gistID: id))
        }
        // Session stays active on pause — the user is likely to resume.
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            pause()
        case .paused, .idle:
            play()
        case .preparing:
            // Toggling mid-regeneration is a no-op; the UI shows "Voicing…"
            // and stop() remains the escape hatch.
            break
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(time, 0), player.duration)
        player.currentTime = clamped
        currentTime = clamped
        pushNowPlaying()
    }

    func skipForward() { skip(by: Self.skipInterval) }
    func skipBackward() { skip(by: -Self.skipInterval) }

    func skip(by interval: TimeInterval) {
        guard let player else { return }
        seek(to: player.currentTime + interval)
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if let player {
            player.rate = newRate
        }
        pushNowPlaying()
    }

    /// Full stop: tears down the player, clears Now Playing, releases the
    /// audio session, cancels any in-flight regeneration.
    func stop() {
        let stoppedID = currentGist?.id
        cancelRegeneration()
        stopProgressUpdates()
        player?.stop()
        player = nil
        delegateProxy = nil
        currentGist = nil
        state = .idle
        currentTime = 0
        duration = 0
        hasFiredPlayedThreshold = false
        nowPlaying.clear()
        session.deactivate()
        if let stoppedID {
            emit(.didStop(gistID: stoppedID))
        }
    }

    // MARK: - Loading

    private func activate(_ gist: PlayableGist, autoplay: Bool) {
        // Same gist, player alive → this is a resume/no-op, not a reload.
        if gist.id == currentGist?.id, player != nil {
            if autoplay, let player { startPlayback(player) }
            return
        }

        // Same gist, already regenerating → don't cancel and restart the
        // pipeline job; the in-flight regeneration will auto-play on success.
        if gist.id == currentGist?.id, state == .preparing {
            return
        }

        // Switching gists: end the previous one cleanly first.
        if currentGist != nil {
            stop()
        }

        currentGist = gist
        currentTime = 0
        hasFiredPlayedThreshold = false
        duration = gist.expectedDuration ?? 0

        if let url = gist.audioFileURL, FileManager.default.fileExists(atPath: url.path) {
            loadPlayer(from: url, autoplay: autoplay)
        } else if autoplay {
            beginRegeneration(for: gist)
        } else {
            // Loaded-but-absent: surfaces can show the gist; play() regenerates.
            state = .idle
        }
    }

    private func loadPlayer(from url: URL, autoplay: Bool) {
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.enableRate = true
            newPlayer.rate = rate
            newPlayer.prepareToPlay()

            let proxy = PlayerDelegateProxy(
                onFinish: { [weak self] successfully in
                    Task { @MainActor [weak self] in
                        self?.handlePlaybackFinished(successfully: successfully)
                    }
                },
                onDecodeError: { [weak self] message in
                    Task { @MainActor [weak self] in
                        self?.handleCorruptAudio(message: message)
                    }
                }
            )
            newPlayer.delegate = proxy

            self.player = newPlayer
            self.delegateProxy = proxy
            self.duration = newPlayer.duration
            self.state = .paused
            pushNowPlaying()

            if autoplay {
                startPlayback(newPlayer)
            }
        } catch {
            // Corrupt file (spec §9): treat as evicted — delete it and fall
            // into the regeneration path.
            Logger.error(error, context: "AVAudioPlayer init failed; treating file as corrupt")
            handleCorruptAudio(message: error.localizedDescription)
        }
    }

    private func startPlayback(_ player: AVAudioPlayer) {
        guard state != .playing else { return }
        do {
            try session.activate()
        } catch {
            // Log and attempt playback anyway — a failed activation usually
            // still plays, just without full session semantics.
            Logger.error(error, context: "Audio session activation failed")
        }
        player.rate = rate
        guard player.play() else {
            Logger.log("AVAudioPlayer.play() returned false", level: .error)
            return
        }
        state = .playing
        startProgressUpdates()
        pushNowPlaying()
        if let id = currentGist?.id {
            emit(.didStartPlaying(gistID: id))
        }
    }

    // MARK: - Regeneration (audio-is-a-cache seam, spec §5/§7)

    private func beginRegeneration(for gist: PlayableGist) {
        guard let handler = regenerationHandler else {
            // Composition-root wiring hasn't happened (or a test forgot to
            // stub it). This is a program error, not a user state.
            Logger.log("Play requested for gist with no audio and no regenerationHandler wired", level: .error)
            state = .idle
            emit(.regenerationFailed(gistID: gist.id, message: "No regeneration handler configured"))
            return
        }

        state = .preparing
        nowPlaying.clear() // Now Playing appears only once real audio plays (spec §5).

        regenerationTask = Task { [weak self] in
            do {
                let url = try await handler(gist)
                guard let self, !Task.isCancelled else { return }
                // The user may have moved on while we were voicing.
                guard self.currentGist?.id == gist.id, self.state == .preparing else { return }
                // Refresh our value copy so audioFileURL reflects the new file.
                self.currentGist = PlayableGist(
                    id: gist.id,
                    title: gist.title,
                    audioFileURL: url,
                    expectedDuration: gist.expectedDuration
                )
                self.loadPlayer(from: url, autoplay: true)
            } catch is CancellationError {
                // stop() or a gist switch cancelled us; nothing to do.
            } catch {
                guard let self, !Task.isCancelled else { return }
                guard self.currentGist?.id == gist.id else { return }
                Logger.error(error, context: "Audio regeneration failed")
                self.state = .idle
                self.emit(.regenerationFailed(gistID: gist.id, message: error.localizedDescription))
            }
        }
    }

    private func cancelRegeneration() {
        regenerationTask?.cancel()
        regenerationTask = nil
    }

    // MARK: - Completion & corruption

    private func handlePlaybackFinished(successfully: Bool) {
        stopProgressUpdates()
        guard let gistID = currentGist?.id else { return }

        if successfully {
            firePlayedThresholdIfNeeded()
            emit(.didFinish(gistID: gistID))
        }
        // AVAudioPlayer rewinds itself after finishing; mirror that so the
        // surfaces show a replay-ready position.
        currentTime = 0
        state = .paused
        nowPlaying.clear()
        session.deactivate()
    }

    private func handleCorruptAudio(message: String) {
        guard let gist = currentGist else { return }
        Logger.log("Corrupt audio for gist \(gist.id): \(message) — deleting and regenerating", level: .warning)

        stopProgressUpdates()
        player?.stop()
        player = nil
        delegateProxy = nil
        currentTime = 0
        duration = gist.expectedDuration ?? 0

        // Best-effort delete of the bad file so the cache can't serve it again.
        if let url = gist.audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        // Fall into the normal missing-audio path. The pipeline's own record
        // normalization (.ready → .scriptReady) happens inside regeneration.
        beginRegeneration(for: gist)
    }

    // MARK: - Session events (interruptions, route changes, resets)

    private func handleSessionEvent(_ event: AudioSessionController.Event) {
        switch event {
        case .interruptionBegan:
            // Call/Siri/other app took audio. Remember intent, reflect pause.
            wasPlayingBeforeInterruption = (state == .playing)
            if state == .playing {
                pause()
            }

        case .interruptionEnded(let shouldResume):
            // Auto-resume ONLY when we were playing and the system says the
            // interruption was transient (spec §4.2). A declined call resumes;
            // the user starting Music does not.
            if wasPlayingBeforeInterruption && shouldResume {
                play()
            }
            wasPlayingBeforeInterruption = false

        case .outputRouteLost:
            // AirPods/headphones disconnected: pause, never blast the speaker.
            if state == .playing {
                pause()
            }

        case .mediaServicesReset:
            // The media daemon died; player object and session are invalid.
            // Rebuild the player at the same position, paused — the user
            // presses play to continue (conservative; auto-resume after a
            // daemon crash risks surprise audio).
            let resumeTime = currentTime
            let gist = currentGist
            player?.stop()
            player = nil
            delegateProxy = nil
            stopProgressUpdates()
            state = .idle
            if let gist, let url = gist.audioFileURL,
               FileManager.default.fileExists(atPath: url.path) {
                loadPlayer(from: url, autoplay: false)
                seek(to: resumeTime)
            }
        }
    }

    // MARK: - Remote commands (lock screen / AirPods / CarPlay)

    private func handleRemoteCommand(_ command: NowPlayingController.Command) {
        switch command {
        case .play: play()
        case .pause: pause()
        case .togglePlayPause: togglePlayPause()
        case .skipForward(let interval): skip(by: interval)
        case .skipBackward(let interval): skip(by: -interval)
        case .changePosition(let position): seek(to: position)
        }
    }

    // MARK: - Progress

    private func startProgressUpdates() {
        stopProgressUpdates()
        // A MainActor task loop instead of Timer: inherits isolation, no
        // nonisolated timer-callback hop needed. 0.5 s per spec §4.2.
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func tick() {
        guard state == .playing, let player else { return }
        currentTime = player.currentTime
        if duration > 0, currentTime >= duration * 0.9 {
            firePlayedThresholdIfNeeded()
        }
    }

    private func firePlayedThresholdIfNeeded() {
        guard !hasFiredPlayedThreshold, let id = currentGist?.id else { return }
        hasFiredPlayedThreshold = true
        emit(.didReachPlayedThreshold(gistID: id))
    }

    // MARK: - Now Playing

    private func pushNowPlaying() {
        guard let gist = currentGist, player != nil else { return }
        nowPlaying.update(NowPlayingController.Snapshot(
            title: gist.title,
            elapsed: currentTime,
            duration: duration,
            rate: rate,
            isPlaying: state == .playing
        ))
    }

    // MARK: - Events

    private func emit(_ event: PlaybackEvent) {
        onEvent?(event)
    }
}

// MARK: - AVAudioPlayerDelegate proxy

/// AVAudioPlayerDelegate callbacks can arrive off the main actor, and the
/// engine is @MainActor — so a small nonisolated NSObject proxy receives them
/// and forwards through @Sendable closures that hop explicitly. This is the
/// hop, made visible, instead of an @unchecked Sendable conformance.
private final class PlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
    private let onFinish: @Sendable (Bool) -> Void
    private let onDecodeError: @Sendable (String) -> Void

    init(
        onFinish: @escaping @Sendable (Bool) -> Void,
        onDecodeError: @escaping @Sendable (String) -> Void
    ) {
        self.onFinish = onFinish
        self.onDecodeError = onDecodeError
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish(flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onDecodeError(error?.localizedDescription ?? "Unknown decode error")
    }
}
