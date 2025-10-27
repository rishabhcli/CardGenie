//
//  DocumentScannerView.swift
//  CardGenie
//
//  VisionKit document scanner wrapper for multi-page scanning with auto-cropping.
//  Provides professional document scanning capabilities when available.
//

import SwiftUI
import VisionKit

/// Result of a document scan operation
struct DocumentScanResult {
    let images: [UIImage]
    let pageCount: Int

    init(images: [UIImage]) {
        self.images = images
        self.pageCount = images.count
    }
}

/// SwiftUI wrapper for VNDocumentCameraViewController
struct DocumentScannerView: UIViewControllerRepresentable {
    @Binding var result: DocumentScanResult?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []

            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                images.append(image)
            }

            parent.result = DocumentScanResult(images: images)
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            print("Document scanning failed: \(error.localizedDescription)")
            parent.dismiss()
        }
    }
}

/// Check if document scanning is available on the current device
struct DocumentScanningCapability {
    static var isAvailable: Bool {
        VNDocumentCameraViewController.isSupported
    }

    static var requiresiOS13: Bool {
        if #available(iOS 13.0, *) {
            return true
        }
        return false
    }
}
