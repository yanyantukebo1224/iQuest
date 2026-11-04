import SwiftUI

struct TrackingDashboard: View {
    @StateObject private var tracking = ARTrackingModel()
    @StateObject private var controller = ControllerInputModel()

    var body: some View {
        ZStack {
            ARPassthroughView(session: tracking.session)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("iQuest").font(.title.bold())
                        Text("MR · HAND TRACKING · QUEST RUNTIME")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.cyan)
                    }
                    Spacer()
                    Circle()
                        .fill(tracking.status.contains("normal") ? .green : .orange)
                        .frame(width: 9, height: 9)
                    Text(tracking.status)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                HStack(alignment: .top, spacing: 12) {
                    handPanel
                    controllerPanel
                }

                posePanel

                Spacer()

                HStack {
                    Text("MR PASSTHROUGH ACTIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(.cyan)
                    Spacer()
                    Text("AR frames: \(tracking.frameCount)")
                        .font(.caption2.monospacedDigit())
                }
                .padding(12)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear { tracking.start() }
        .onDisappear { tracking.stop() }
    }

    private var posePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Head / Device 6DoF", systemImage: "move.3d")
                    .font(.headline)
                Spacer()
                Button("Recenter") { tracking.reset() }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(.cyan)
            }
            let p = tracking.position
            let q = tracking.orientation
            Text(String(format: "Position  X %+.3f  Y %+.3f  Z %+.3f m", p.x, p.y, p.z))
                .font(.system(size: 11, design: .monospaced))
            Text(String(format: "Rotation  X %+.3f  Y %+.3f  Z %+.3f  W %+.3f", q.vector.x, q.vector.y, q.vector.z, q.vector.w))
                .font(.system(size: 11, design: .monospaced))
            Text("ARKit world-space camera pose · 3 translational + 3 rotational degrees")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var handPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("3D Finger Tracking", systemImage: "hand.draw")
                .font(.headline)
            Text(tracking.handStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
            if tracking.hands.isEmpty {
                Text("Show your hands to the rear camera")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tracking.hands) { hand in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(hand.chirality)
                            Spacer()
                            Text("\(Int(hand.confidence * 100))%")
                        }
                        .font(.caption.bold())
                        Text("\(hand.joints.count)/21 joints")
                            .font(.caption2.monospaced())
                        if let wrist = hand.joints["wrist"] {
                            Text(String(format: "Wrist %.2f / %.2f / %.2f m", wrist.x, wrist.y, wrist.z))
                                .font(.system(size: 9, design: .monospaced))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controllerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Controller Bridge", systemImage: "gamecontroller")
                .font(.headline)
            Text(controller.status)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(controller.controllerName)
                .font(.caption.bold())
            stickRow("Left stick", controller.leftStick)
            stickRow("Right stick", controller.rightStick)
            Text(controller.pressedButtons.sorted().joined(separator: " · ").isEmpty
                 ? "No buttons pressed"
                 : controller.pressedButtons.sorted().joined(separator: " · "))
                .font(.caption2.monospaced())
                .lineLimit(3)
            Text("Controller IMU intentionally unused")
                .font(.caption2)
                .foregroundStyle(.cyan)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stickRow(_ label: String, _ value: SIMD2<Float>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "X %+.2f  Y %+.2f", value.x, value.y))
                .font(.system(size: 10, design: .monospaced))
        }
    }
}
