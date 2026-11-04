import Foundation
import Combine

@MainActor
final class GameLibraryModel: ObservableObject {
    @Published private(set) var selectedAPK: URL?
    @Published private(set) var status = "Import a Quest APK to add it to your library."

    private var securityScopedURL: URL?

    func importAPK(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            status = "Import failed: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else {
                status = "No file was selected."
                return
            }
            guard url.pathExtension.lowercased() == "apk" else {
                status = "That file is not an APK."
                return
            }

            releaseSelectedFile()
            let hasScope = url.startAccessingSecurityScopedResource()
            securityScopedURL = hasScope ? url : nil
            selectedAPK = url
            status = "APK selected. Guest runtime is not connected yet."
        }
    }

    func clearSelection() {
        releaseSelectedFile()
        selectedAPK = nil
        status = "Import a Quest APK to add it to your library."
    }

    func requestLaunch() {
        guard selectedAPK != nil else {
            status = "Select an APK first."
            return
        }
        // Deliberately do not simulate a successful launch. The iOS target
        // does not yet link the Klepton guest lifecycle/graphics runtime.
        status = "Cannot launch yet: the Klepton iOS guest runtime is not linked."
    }

    private func releaseSelectedFile() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }
}
