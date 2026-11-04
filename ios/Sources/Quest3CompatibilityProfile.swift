import ARKit
import Foundation

enum Quest3FeatureLevel: String {
    case mapped = "Mapped"
    case partial = "Partial"
    case unavailable = "Unavailable"
}

struct Quest3Feature: Identifiable {
    let id: String
    let questAPI: String
    let level: Quest3FeatureLevel
    let hostAPI: String
    let note: String
}

enum Quest3CompatibilityProfile {
    // This is an iPhone-host capability profile, not a claim that iOS is a
    // Meta Horizon OS runtime. Unsupported Meta extensions must never be
    // advertised to an OpenXR guest as implemented.
    static var features: [Quest3Feature] {
        let worldTracking = ARWorldTrackingConfiguration.isSupported
        let sceneMesh = worldTracking &&
            ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        let sceneDepth = worldTracking &&
            ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)

        return [
            Quest3Feature(
                id: "head-pose",
                questAPI: "XR_VIEW_CONFIGURATION_TYPE_PRIMARY_STEREO",
                level: worldTracking ? .partial : .unavailable,
                hostAPI: "ARKit ARSession",
                note: "6DoF phone pose is available; it is not a tracked Quest headset pose."
            ),
            Quest3Feature(
                id: "passthrough",
                questAPI: "XR_FB_passthrough",
                level: worldTracking ? .partial : .unavailable,
                hostAPI: "ARKit camera background",
                note: "Camera imagery can be displayed locally. This is not Meta's protected compositor passthrough layer."
            ),
            Quest3Feature(
                id: "hand-tracking",
                questAPI: "XR_EXT_hand_tracking / XR_FB_hand_tracking_mesh",
                level: .partial,
                hostAPI: "Vision VNDetectHumanHandPoseRequest",
                note: "2D landmarks with monocular depth approximation; not Quest-quality articulated 3D tracking."
            ),
            Quest3Feature(
                id: "scene-understanding",
                questAPI: "XR_FB_scene / XR_FB_scene_capture",
                level: sceneMesh ? .partial : .unavailable,
                hostAPI: "ARKit plane detection",
                note: sceneMesh
                    ? "ARKit mesh reconstruction is available, but Quest Scene API semantics still need an adapter."
                    : "Plane detection only; this device does not expose ARKit scene mesh reconstruction."
            ),
            Quest3Feature(
                id: "environment-depth",
                questAPI: "XR_META_environment_depth",
                level: sceneDepth ? .partial : .unavailable,
                hostAPI: "ARFrame.sceneDepth",
                note: sceneDepth
                    ? "ARKit depth is available, but it is not the Meta environment-depth extension."
                    : "No scene-depth frame semantics on this device; do not emulate depth with fabricated values."
            ),
            Quest3Feature(
                id: "spatial-anchors",
                questAPI: "XR_FB_spatial_entity",
                level: .partial,
                hostAPI: "ARAnchor",
                note: "World anchors can be created in an AR session; Meta persistence, sharing and UUID semantics are not implemented."
            ),
            Quest3Feature(
                id: "controller-input",
                questAPI: "XR_ACTION_TYPE_BOOLEAN_INPUT / VECTOR2F_INPUT",
                level: .partial,
                hostAPI: "GameController extended gamepad",
                note: "Buttons and sticks only. No Joy-Con IMU or controller 6DoF pose is consumed."
            ),
            Quest3Feature(
                id: "stereo-compositor",
                questAPI: "xrWaitFrame / xrBeginFrame / xrEndFrame",
                level: .unavailable,
                hostAPI: "No iOS equivalent for a Quest HMD compositor",
                note: "A phone display is not a dual-eye Quest display. A split-screen demo is not true stereo XR."
            ),
            Quest3Feature(
                id: "eye-face-body",
                questAPI: "XR_FB_eye_tracking_social / XR_FB_face_tracking / XR_FB_body_tracking",
                level: .unavailable,
                hostAPI: "No compatible host sensor/API",
                note: "These Quest tracking extensions are not exposed by this iPhone host."
            )
        ]
    }

    static var summary: String {
        let mapped = features.filter { $0.level == .mapped }.count
        let partial = features.filter { $0.level == .partial }.count
        let unavailable = features.filter { $0.level == .unavailable }.count
        return "\(mapped) mapped · \(partial) partial · \(unavailable) unavailable"
    }
}
