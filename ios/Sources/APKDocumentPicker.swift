import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Presents the system document picker directly from a lightweight UIKit host.
/// Keeping UIDocumentPickerViewController out of a nested SwiftUI sheet avoids
/// the extra presentation layer that can interfere with file-provider selection.
struct APKDocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented else { return }

        DispatchQueue.main.async {
            context.coordinator.presentPicker(from: controller)
        }
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: APKDocumentPicker
        private var isPickerPresented = false

        init(parent: APKDocumentPicker) {
            self.parent = parent
        }

        func presentPicker(from presenter: UIViewController) {
            guard parent.isPresented, !isPickerPresented,
                  presenter.viewIfLoaded?.window != nil,
                  presenter.presentedViewController == nil else {
                return
            }

            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.item],
                asCopy: true
            )
            picker.allowsMultipleSelection = false
            picker.shouldShowFileExtensions = true
            picker.delegate = self
            isPickerPresented = true
            presenter.present(picker, animated: true)
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            isPickerPresented = false
            parent.isPresented = false
            guard let url = urls.first else {
                parent.onCancel()
                return
            }
            parent.onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            isPickerPresented = false
            parent.isPresented = false
            parent.onCancel()
        }
    }
}
