import ARKit
import Combine
import Foundation
import Vision
import simd
import CoreVideo

struct TrackedHand: Identifiable {
    let id: UUID
    let chirality: String
    let joints: [String: SIMD3<Float>]
    let confidence: Float
}

@MainActor
final class ARTrackingModel: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "Not started"
    @Published private(set) var position = SIMD3<Float>(repeating: 0)
    @Published private(set) var orientation = simd_quatf(real: 1, imag: .zero)
    @Published private(set) var frameCount: UInt64 = 0
    @Published private(set) var lastFrameTime: TimeInterval = 0
    @Published private(set) var hands: [TrackedHand] = []
    @Published private(set) var handStatus = "Waiting for camera frames"

    let session = ARSession()
    private let visionQueue = DispatchQueue(label: "dev.iquest.hand-vision", qos: .userInteractive)
    private var lastVisionTimestamp: TimeInterval = 0

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
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
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
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        frameCount = 0
        hands = []
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

    private func publishHands(_ detected: [TrackedHand], status: String) {
        hands = detected
        handStatus = status
    }

    nonisolated func processHands(frame: ARFrame) {
        let timestamp = frame.timestamp
        guard timestamp - lastVisionTimestamp >= 1.0 / 30.0 else { return }
        lastVisionTimestamp = timestamp
        let pixelBuffer = frame.capturedImage
        let camera = frame.camera
        let cameraTransform = camera.transform
        let intrinsics = camera.intrinsics
        let width = Float(CVPixelBufferGetWidth(pixelBuffer))
        let height = Float(CVPixelBufferGetHeight(pixelBuffer))

        visionQueue.async { [weak self] in
            let request = VNDetectHumanHandPoseRequest()
            request.maximumHandCount = 2
            do {
                try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up).perform([request])
                let observations = request.results ?? []
                let mapped: [TrackedHand] = observations.compactMap { observation in
                    guard let points = try? observation.recognizedPoints(.all) else { return nil }
                    let jointNames: [(VNHumanHandPoseObservation.JointName, String)] = [
                        (.wrist, "wrist"),
                        (.thumbCMC, "thumbCMC"), (.thumbMP, "thumbMP"), (.thumbIP, "thumbIP"), (.thumbTip, "thumbTip"),
                        (.indexMCP, "indexMCP"), (.indexPIP, "indexPIP"), (.indexDIP, "indexDIP"), (.indexTip, "indexTip"),
                        (.middleMCP, "middleMCP"), (.middlePIP, "middlePIP"), (.middleDIP, "middleDIP"), (.middleTip, "middleTip"),
                        (.ringMCP, "ringMCP"), (.ringPIP, "ringPIP"), (.ringDIP, "ringDIP"), (.ringTip, "ringTip"),
                        (.littleMCP, "littleMCP"), (.littlePIP, "littlePIP"), (.littleDIP, "littleDIP"), (.littleTip, "littleTip")
                    ]
                    let index = points[.indexMCP]
                    let little = points[.littleMCP]
                    var depth: Float = 0.55
                    if let index, let little,
                       index.confidence > 0.15, little.confidence > 0.15 {
                        let dx = Float(index.location.x - little.location.x) * width
                        let dy = Float(index.location.y - little.location.y) * height
                        let pixelSpan = max(1, hypotf(dx, dy))
                        let fx = intrinsics.columns.0.x
                        depth = min(1.25, max(0.22, fx * 0.085 / pixelSpan))
                    }

                    var joints: [String: SIMD3<Float>] = [:]
                    var confidence: Float = 0
                    var count: Float = 0
                    for (joint, name) in jointNames {
                        guard let point = points[joint], point.confidence > 0.10 else { continue }
                        let px = Float(point.location.x) * width
                        let py = (1 - Float(point.location.y)) * height
                        let fx = intrinsics.columns.0.x
                        let fy = intrinsics.columns.1.y
                        let cx = intrinsics.columns.2.x
                        let cy = intrinsics.columns.2.y
                        let local = SIMD4<Float>((px - cx) * depth / fx,
                                                 -(py - cy) * depth / fy,
                                                 -depth, 1)
                        let world = cameraTransform * local
                        joints[name] = SIMD3<Float>(world.x, world.y, world.z)
                        confidence += point.confidence
                        count += 1
                    }
                    guard !joints.isEmpty else { return nil }
                    let side = observation chirality == .left ? "Left" : "Right"
                    return TrackedHand(id: UUID(), chirality: side, joints: joints,
                                       confidence: count > 0 ? confidence / count : 0)
                }
                let summary = mapped.isEmpty ? "No hands detected — keep both hands in view" : "\(mapped.count) hand(s), 21-joint model"
                Task { @MainActor [weak self] in self?.publishHands(mapped, status: summary) }
            } catch {
                let message = error.localizedDescription
                Task { @MainActor [weak self] in self?.publishHands([], status: "Vision error: \(message)") }
            }
        }
    }
}

extension ARTrackingModel: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let orientation = simd_quatf(transform)
        let tracking: String
        switch frame.camera.trackingState {
        case .normal: tracking = "Tracking: normal"
        case .notAvailable: tracking = "Tracking unavailable"
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
        processHands(frame: frame)
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
