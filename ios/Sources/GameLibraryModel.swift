import Foundation
import Combine

@MainActor
final class GameLibraryModel: ObservableObject {
    @Published private(set) var selectedAPK: URL?
    @Published private(set) var status = "Import a Quest APK to add it to your library."

    private var importedFileURL: URL?

    func statusMessage(_ message: String) {
        status = message
    }

    func importAPK(from sourceURL: URL) {
        guard sourceURL.pathExtension.lowercased() == "apk" else {
            status = "Not an APK: \(sourceURL.lastPathComponent)"
            return
        }

        do {
            let fileManager = FileManager.default
            let supportDirectory = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let importDirectory = supportDirectory.appendingPathComponent("ImportedAPKs", isDirectory: true)
            try fileManager.createDirectory(
                at: importDirectory,
                withIntermediateDirectories: true
            )

            let destinationURL = importDirectory.appendingPathComponent(
                UUID().uuidString + "-" + sourceURL.lastPathComponent,
                isDirectory: false
            )
            try fileManager.copyItem(at: sourceURL, to: destinationURL)

            removeImportedFile()
            importedFileURL = destinationURL
            selectedAPK = destinationURL
            status = "Imported successfully: \(sourceURL.lastPathComponent)"
        } catch {
            status = "Could not import APK: \(error.localizedDescription)"
        }
    }

    func clearSelection() {
        removeImportedFile()
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

    private func removeImportedFile() {
        if let importedFileURL {
            try? FileManager.default.removeItem(at: importedFileURL)
        }
        importedFileURL = nil
    }
}
