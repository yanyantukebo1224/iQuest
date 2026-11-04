import Foundation
import Combine

@MainActor
final class GameLibraryModel: ObservableObject {
    @Published private(set) var selectedAPK: URL?
    @Published private(set) var inspection: APKInspection?
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

            let metadata = try APKInspection.read(from: destinationURL)
            removeImportedFile()
            importedFileURL = destinationURL
            selectedAPK = destinationURL
            inspection = metadata
            status = "Imported and inspected: \(sourceURL.lastPathComponent)"
        } catch {
            status = "APK import/inspection failed: \(error.localizedDescription)"
        }
    }

    func clearSelection() {
        removeImportedFile()
        selectedAPK = nil
        inspection = nil
        status = "Import a Quest APK to add it to your library."
    }

    func requestLaunch() {
        guard let selectedAPK, let inspection else {
            status = "Select and inspect an APK first."
            return
        }
        let frameworks = Bundle.main.privateFrameworksURL
        let missing = inspection.missingTranslatedLibraries(in: frameworks)
        if let entry = inspection.entryLibrary,
           missing.contains(entry) {
            status = "Cannot launch: \(entry) has no pretranslated, signed iOS framework in this IPA. APK import alone cannot provide executable code on iOS."
            return
        }
        if inspection.entryLibrary == nil {
            status = "Cannot launch: no supported native entry library was identified in this APK."
            return
        }
        if !missing.isEmpty {
            status = "Cannot launch: \(missing.count) native libraries still need pretranslation and signing (for example \(missing.prefix(3).joined(separator: ", ")))."
            return
        }
        status = "Native libraries are present. The iOS guest lifecycle and stereo compositor still need to be connected before this title can start."
        _ = selectedAPK
    }

    private func removeImportedFile() {
        if let importedFileURL {
            try? FileManager.default.removeItem(at: importedFileURL)
        }
        importedFileURL = nil
    }
}
