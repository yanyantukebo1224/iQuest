import SwiftUI
import UniformTypeIdentifiers

struct GameLauncherView: View {
    @StateObject private var library = GameLibraryModel()
    @State private var isImporterPresented = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.035, green: 0.045, blue: 0.075),
                         Color(red: 0.075, green: 0.085, blue: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "visionpro")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("iQuest")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("QUEST GAME LIBRARY")
                                .font(.caption2.weight(.bold))
                                .tracking(2.2)
                                .foregroundStyle(.cyan)
                        }
                        Spacer(minLength: 8)
                        Circle()
                            .fill(.orange)
                            .frame(width: 8, height: 8)
                        Text("RUNTIME SETUP")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Quest games, on iPhone.")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Import an Android Quest APK to add it to your local library. Games will run on-device when the Klepton iOS runtime is connected.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            isImporterPresented = true
                        } label: {
                            Label("Import Quest APK", systemImage: "plus.app")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("Selected game", systemImage: "gamecontroller")
                                .font(.headline)
                            Spacer()
                            if library.selectedAPK != nil {
                                Button("Remove", role: .destructive) {
                                    library.clearSelection()
                                }
                                .font(.caption)
                            }
                        }

                        if let apk = library.selectedAPK {
                            HStack(spacing: 12) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.cyan)
                                    .frame(width: 54, height: 54)
                                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(apk.lastPathComponent)
                                        .font(.headline)
                                        .lineLimit(2)
                                        .textSelection(.enabled)
                                    Text("Copied into iQuest · Android APK")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                "No games yet",
                                systemImage: "square.stack.3d.up",
                                description: Text("Choose an .apk file using the import button.")
                            )
                            .frame(minHeight: 130)
                        }

                        Divider().overlay(.white.opacity(0.12))

                        Button {
                            library.requestLaunch()
                        } label: {
                            Label("Start game", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(library.selectedAPK == nil)

                        Text(library.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Guest execution is not available in this build yet.")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))

                    HStack {
                        Text("LOCAL ONLY")
                        Spacer()
                        Text("iOS · ARM64")
                    }
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 26)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            library.importAPK(result)
        }
    }
}
