//
//  NowPlayingController.swift
//  Gista
//
//  Created by Tony Nlemadim on 7/25/26.
//
//  Owns MPNowPlayingInfoCenter and MPRemoteCommandCenter for the single
//  playback engine (spec §4.2). This is what makes the lock screen, AirPods,
//  and CarPlay controls work — it belongs to the engine, not to the Live
//  Activity (spec §8).
//
//  MPRemoteCommandCenter handlers are not guaranteed to arrive on the main
//  actor. Each handler extracts any Sendable payload it needs (skip interval,
//  seek position), hops to the main actor explicitly, and returns `.success`
//  synchronously. No @unchecked Sendable anywhere.
//

import Foundation
import MediaPlayer

@MainActor
final class NowPlayingController {

    /// Remote commands, already normalized. Delivered on the main actor.
    enum Command: Equatable, Sendable {
        case play
        case pause
        case togglePlayPause
        case skipForward(TimeInterval)
        case skipBackward(TimeInterval)
        case changePosition(TimeInterval)
    }

    /// What the lock screen shows. The engine pushes a snapshot on every
    /// discrete state change (load/play/pause/seek/rate); the system
    /// extrapolates elapsed time from `rate` between pushes.
    struct Snapshot: Equatable, Sendable {
        var title: String
        var elapsed: TimeInterval
        var duration: TimeInterval
        var rate: Float
        var isPlaying: Bool
    }

    /// Set by the engine. Always invoked on the main actor.
    var onCommand: ((Command) -> Void)?

    /// Skip interval advertised to the system (spec: ±15 s).
    let skipInterval: TimeInterval

    private var registeredCommands: [MPRemoteCommand] = []
    private var isSetUp = false

    init(skipInterval: TimeInterval = 15) {
        self.skipInterval = skipInterval
    }

    // MARK: - Now Playing info

    func update(_ snapshot: Snapshot) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyPlaybackDuration: snapshot.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.isPlaying ? Double(snapshot.rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(snapshot.rate),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        // Artwork: placeholder-free in v1; thumbnail artwork arrives with the
        // rewire wave (spec M4) once GistRecord thumbnails are wired through.
        info[MPMediaItemPropertyArtist] = "Gista"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote commands

    /// Registers all handlers. Idempotent. Call once when the engine is created.
    func setUp() {
        guard !isSetUp else { return }
        isSetUp = true

        let center = MPRemoteCommandCenter.shared()

        register(center.playCommand) { _ in .play }
        register(center.pauseCommand) { _ in .pause }
        register(center.togglePlayPauseCommand) { _ in .togglePlayPause }

        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        let defaultSkip = skipInterval
        register(center.skipForwardCommand) { event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? defaultSkip
            return .skipForward(interval)
        }
        register(center.skipBackwardCommand) { event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? defaultSkip
            return .skipBackward(interval)
        }

        register(center.changePlaybackPositionCommand) { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return nil }
            return .changePosition(positionEvent.positionTime)
        }

        // Single-track app: prev/next are meaningless and would clutter CarPlay.
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
    }

    /// Unregisters every handler. The engine is app-lifetime, so this exists
    /// for tests and completeness rather than a production code path.
    func tearDown() {
        for command in registeredCommands {
            command.removeTarget(nil)
        }
        registeredCommands.removeAll()
        isSetUp = false
    }

    // MARK: - Private

    /// `map` runs in the handler's (nonisolated) context and must only touch
    /// the Sendable event payload; the resulting Command is hopped to the
    /// main actor for dispatch.
    private func register(
        _ command: MPRemoteCommand,
        map: @escaping @Sendable (MPRemoteCommandEvent) -> Command?
    ) {
        command.isEnabled = true
        command.addTarget { [weak self] event in
            guard let mapped = map(event) else { return .commandFailed }
            Task { @MainActor [weak self] in
                self?.onCommand?(mapped)
            }
            return .success
        }
        registeredCommands.append(command)
    }
}
