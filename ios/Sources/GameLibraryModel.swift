import Foundation
import Combine

@MainActor
final class GameLibraryModel: ObservableObject {
    @Published private(set) var selectedAPK: URL?
    @Published private(set) var status = "Import a Quest APK to add it to your library."

    private var importedFileURL: URL?

    func importAPK(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            status = "Import failed: \(error.localizedDescription)"

        case .success(let urls):
            guard let sourceURL = urls.first else {
                status = "No file was selected."
                return
            }

            guard sourceURL.pathExtension.lowercased() == "apk" else {
                status = "The selected file is not an APK (\(sourceURL.lastPathComponent))."
                return
            }

            let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
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
                status = "Could not copy APK: \(error.localizedDescription)"
            }
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
