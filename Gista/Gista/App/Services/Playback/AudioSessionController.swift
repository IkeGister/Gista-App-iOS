//
//  AudioSessionController.swift
//  Gista
//
//  Created by Tony Nlemadim on 7/25/26.
//
//  Owns the AVAudioSession for the single playback engine (spec §4.2 / §9).
//  Responsibilities:
//    - Category `.playback` + mode `.spokenAudio` so audio continues when the
//      screen locks or the app is backgrounded (also requires the
//      `UIBackgroundModes: audio` Info.plist key on the app target).
//    - Activation on play, deactivation (notifying others) on stop/completion.
//    - Translating AVAudioSession notifications — interruption, route change,
//      media-services reset — into Sendable events delivered on the main actor.
//
//  AVAudioSession notifications arrive on an arbitrary thread. This class
//  parses each notification's userInfo into value types inside the nonisolated
//  observer closure, then hops to the main actor explicitly. No @unchecked
//  Sendable anywhere.
//

import Foundation
import AVFoundation

@MainActor
final class AudioSessionController {

    /// Session events, already normalized for the engine. Delivered on the main actor.
    enum Event: Equatable, Sendable {
        /// Interruption started (incoming call, Siri, another app took audio).
        /// The system has already paused/ducked us; the engine should reflect a paused state.
        case interruptionBegan
        /// Interruption ended. `shouldResume` is true iff the system included
        /// `AVAudioSession.InterruptionOptions.shouldResume`.
        case interruptionEnded(shouldResume: Bool)
        /// The previous output route disappeared (headphones/AirPods disconnected).
        /// Platform convention: pause rather than continue on the speaker.
        case outputRouteLost
        /// Media services daemon was reset; players and session config are invalid
        /// and must be rebuilt.
        case mediaServicesReset
    }

    /// Set by the engine. Always invoked on the main actor.
    var onEvent: ((Event) -> Void)?

    private var observers: [NSObjectProtocol] = []
    private var isConfigured = false

    init() {
        startObserving()
    }

    deinit {
        // Stored-property access in deinit has exclusive access; removing
        // observers is thread-safe.
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Session control

    /// Sets category `.playback`, mode `.spokenAudio`. Idempotent.
    func configure() throws {
        guard !isConfigured else { return }
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        isConfigured = true
    }

    /// Activates the session. Call immediately before starting playback.
    func activate() throws {
        try configure()
        try AVAudioSession.sharedInstance().setActive(true)
    }

    /// Deactivates the session, letting interrupted apps (music, podcasts) resume.
    /// Call on stop and on natural completion — not on a plain pause.
    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Deactivation can fail benignly (e.g. I/O still running); log and move on.
            Logger.log("Audio session deactivation failed: \(error.localizedDescription)", level: .warning)
        }
    }

    /// Called after `.mediaServicesReset`: forces category re-application on next activate.
    func markNeedsReconfiguration() {
        isConfigured = false
    }

    // MARK: - Notifications

    private func startObserving() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            // Nonisolated context: extract Sendable values before hopping.
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            switch type {
            case .began:
                Task { @MainActor [weak self] in
                    self?.onEvent?(.interruptionBegan)
                }
            case .ended:
                let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
                Task { @MainActor [weak self] in
                    self?.onEvent?(.interruptionEnded(shouldResume: shouldResume))
                }
            @unknown default:
                break
            }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: nil
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
            else { return }

            // Only `.oldDeviceUnavailable` (headphones yanked) demands action.
            // `.newDeviceAvailable` (AirPods connected) must NOT auto-play.
            guard reason == .oldDeviceUnavailable else { return }
            Task { @MainActor [weak self] in
                self?.onEvent?(.outputRouteLost)
            }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.markNeedsReconfiguration()
                self?.onEvent?(.mediaServicesReset)
            }
        })
    }
}
