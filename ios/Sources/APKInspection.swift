import Foundation

struct APKInspection: Identifiable {
    let id = UUID()
    let packageName: String
    let version: String
    let fileBytes: Int64
    let arm64Libraries: [String]
    let assetFileCount: Int
    let manifestPresent: Bool

    var entryLibrary: String? {
        let candidates = ["libmain.so", "libUE4.so", "libopenjk_ja.so",
                          "libopenjk_jo.so", "libmiamivr.so", "libxash.so",
                          "liblauncher.so", "libvrlink_scene.so"]
        return candidates.first(where: { arm64Libraries.contains($0) })
    }

    var engineHint: String {
        guard let entryLibrary else {
            return arm64Libraries.isEmpty ? "No ARM64 native libraries found" : "Unknown native entry point"
        }
        switch entryLibrary {
        case "libmain.so": return "Unity / NativeLoader"
        case "libUE4.so": return "Unreal Engine"
        case "libopenjk_ja.so", "libopenjk_jo.so": return "OpenJK XR"
        case "libmiamivr.so": return "Native OpenXR"
        case "libxash.so", "liblauncher.so": return "SDL / Source engine"
        case "libvrlink_scene.so": return "Steam Link VR"
        default: return "Native ARM64 application"
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileBytes, countStyle: .file)
    }

    static func read(from url: URL) throws -> APKInspection {
        var report = [CChar](repeating: 0, count: 32_768)
        var error = [CChar](repeating: 0, count: 1_024)
        let result = url.path.withCString { path in
            report.withUnsafeMutableBufferPointer { output in
                error.withUnsafeMutableBufferPointer { err in
                    iquest_apk_inspect(path, output.baseAddress, output.count,
                                       err.baseAddress, err.count)
                }
            }
        }
        guard result == 0 else {
            throw NSError(domain: "iQuest.APKInspector", code: Int(result),
                          userInfo: [NSLocalizedDescriptionKey: String(cString: error)])
        }

        let text = String(cString: report)
        var values: [String: String] = [:]
        var libraries: [String] = []
        for line in text.split(separator: "\n") {
            guard let split = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<split])
            let value = String(line[line.index(after: split)...])
            if key == "arm64_library" { libraries.append(value) }
            else { values[key] = value }
        }
        guard let bytes = Int64(values["file_bytes"] ?? "") else {
            throw NSError(domain: "iQuest.APKInspector", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "APK inspection returned incomplete metadata"])
        }
        return APKInspection(
            packageName: values["package"] ?? "(unknown)",
            version: values["version"] ?? "(unknown)",
            fileBytes: bytes,
            arm64Libraries: libraries,
            assetFileCount: Int(values["asset_file_count"] ?? "") ?? 0,
            manifestPresent: values["manifest"] == "present"
        )
    }

    func missingTranslatedLibraries(in frameworksURL: URL?) -> [String] {
        let replaced: Set<String> = ["libOVRPlugin.so", "libovrplatformloader.so",
                                     "libvrapi.so", "libfrda.so", "libscript.so"]
        let required = arm64Libraries.filter { !replaced.contains($0) }
        guard let frameworksURL else { return required }
        return required.filter { library in
            let stem = String(library.dropLast(3))
            let executable = frameworksURL.appendingPathComponent("\(stem).framework/\(stem)")
            return !FileManager.default.fileExists(atPath: executable.path)
        }
    }
}
