import ARKit
import Combine
import Foundation
import simd

@MainActor
final class ARTrackingModel: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Not started"
    @Published private(set) var position = SIMD3<Float>(repeating: 0)
    @Published private(set) var orientation = simd_quatf(real: 1, imag: .zero)
    @Published private(set) var frameCount: UInt64 = 0
    @Published private(set) var lastFrameTime: TimeInterval = 0

    let session = ARSession()

    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = DispatchQueue(label: "dev.iquest.arkit.delegate", qos: .userInteractive)
    }

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            status = "ARWorldTracking is not supported on this device"
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = []
        configuration.environmentTexturing = .none
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        status = "Starting ARKit world tracking…"
    }

    func stop() {
        session.pause()
        isRunning = false
        status = "Paused"
    }

    func reset() {
        guard isRunning else { start(); return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = []
        configuration.environmentTexturing = .none
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        frameCount = 0
        position = .zero
        orientation = simd_quatf(real: 1, imag: .zero)
        status = "Resetting tracking…"
    }

    private func update(position: SIMD3<Float>, orientation: simd_quatf,
                        tracking: String, timestamp: TimeInterval) {
        self.position = position
        self.orientation = orientation
        self.status = tracking
        self.frameCount &+= 1
        self.lastFrameTime = timestamp
    }
}

extension ARTrackingModel: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        let position = SIMD3<Float>(transform.columns.3.x,
                                    transform.columns.3.y,
                                    transform.columns.3.z)
        let orientation = simd_quatf(transform)
        let tracking: String
        switch frame.camera.trackingState {
        case .normal:
            tracking = "Tracking: normal"
        case .notAvailable:
            tracking = "Tracking unavailable"
        case .limited(let reason):
            switch reason {
            case .initializing: tracking = "Tracking: initializing"
            case .excessiveMotion: tracking = "Tracking limited: excessive motion"
            case .insufficientFeatures: tracking = "Tracking limited: insufficient visual features"
            case .relocalizing: tracking = "Tracking: relocalizing"
            @unknown default: tracking = "Tracking limited: unknown reason"
            }
        }
        let timestamp = frame.timestamp

        Task { @MainActor [weak self] in
            self?.update(position: position, orientation: orientation,
                         tracking: tracking, timestamp: timestamp)
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.status = "ARKit error: \(message)"
            self?.isRunning = false
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor [weak self] in self?.status = "AR session interrupted" }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor [weak self] in self?.status = "AR session resumed; waiting for tracking" }
    }
}
