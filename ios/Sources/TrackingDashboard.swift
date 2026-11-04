import SwiftUI

struct TrackingDashboard: View {
    @StateObject private var tracking = ARTrackingModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("iQuest 16e")
                            .font(.largeTitle.bold())
                        Text("Native ARKit tracking proof of concept")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Circle()
                            .fill(tracking.status.contains("normal") ? .green : .orange)
                            .frame(width: 10, height: 10)
                        Text(tracking.status)
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                    GroupBox("6DoF pose — camera in AR world") {
                        VStack(alignment: .leading, spacing: 10) {
                            vectorRow("X", tracking.position.x)
                            vectorRow("Y", tracking.position.y)
                            vectorRow("Z", tracking.position.z)
                            Divider()
                            vectorRow("Quaternion X", tracking.orientation.vector.x)
                            vectorRow("Quaternion Y", tracking.orientation.vector.y)
                            vectorRow("Quaternion Z", tracking.orientation.vector.z)
                            vectorRow("Quaternion W", tracking.orientation.vector.w)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GroupBox("Runtime diagnostics") {
                        VStack(alignment: .leading, spacing: 8) {
                            diagnostic("AR frames", "\(tracking.frameCount)")
                            diagnostic("Last AR timestamp", String(format: "%.3f s", tracking.lastFrameTime))
                            diagnostic("Device target", "iPhone 16e / arm64")
                            diagnostic("JIT", "Not required by this prototype")
                        }
                    }

                    HStack {
                        Button(tracking.isRunning ? "Pause tracking" : "Start tracking") {
                            tracking.isRunning ? tracking.stop() : tracking.start()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Reset") { tracking.reset() }
                            .buttonStyle(.bordered)
                    }

                    Text("This milestone verifies ARKit world tracking only. It does not yet load Android APKs, run Quest games, provide stereo VR output, or implement OpenXR/OVRP compatibility.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("iQuest")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { tracking.start() }
            .onDisappear { tracking.stop() }
        }
        .preferredColorScheme(.dark)
    }

    private func vectorRow(_ label: String, _ value: Float) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "% .5f", value))
                .monospacedDigit()
                .monospaced()
        }
        .font(.system(.body, design: .monospaced))
    }

    private func diagnostic(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospaced()
        }
        .font(.footnote)
    }
}
