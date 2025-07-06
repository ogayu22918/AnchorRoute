import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    @ObservedObject var visionProcessor: VisionProcessor

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.visionProcessor = visionProcessor
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
