import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct APKDocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: APKDocumentPicker

        init(parent: APKDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.isPresented = false
                parent.onCancel()
                return
            }
            parent.isPresented = false
            parent.onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
            parent.onCancel()
        }
    }
}
