import Foundation
import AVFoundation
import Vision
import SwiftUI

class VisionProcessor: ObservableObject {
    @Published var matchingScore: Float = 0.0

    var recordedFeaturePrints: [VNFeaturePrintObservation] = []
    private var referenceFeaturePrints: [VNFeaturePrintObservation] = []
    private var isRecording = false
    private var isDetecting = false
    private var recordingTimer: Timer?
    private let recordingDuration: TimeInterval = 5.0
    private var recentScores: [Float] = []
    private let scoreBufferSize = 5
    private var lastCIImage: CIImage?

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordedFeaturePrints.removeAll()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: recordingDuration, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .recordingFinished, object: nil)
        }
    }

    func startDetecting(with featurePrints: [VNFeaturePrintObservation]) {
        referenceFeaturePrints = featurePrints
        isDetecting = true
        recentScores.removeAll()
    }

    func stopDetecting() {
        guard isDetecting else { return }
        isDetecting = false
        matchingScore = 0.0
        recentScores.removeAll()
    }

    func getSnapshotData() -> Data? {
        guard let ciImage = lastCIImage else { return nil }
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            return uiImage.jpegData(compressionQuality: 0.8)
        }
        return nil
    }

    func processFrame(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let adjustedImage = self.adjustImage(ciImage, brightness: 0.1, contrast: 1.2)
            DispatchQueue.main.async {
                self.lastCIImage = adjustedImage
            }
            let personSegmentationRequest = VNGeneratePersonSegmentationRequest()
            personSegmentationRequest.qualityLevel = .fast
            personSegmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
            
            let requestHandler = VNImageRequestHandler(ciImage: adjustedImage, options: [:])
            do {
                try requestHandler.perform([personSegmentationRequest])
                guard let maskPixelBuffer = personSegmentationRequest.results?.first?.pixelBuffer else { return }
                
                let downsampledImage = self.downsampleCIImage(adjustedImage)
                let maskedImage = self.applyMask(to: downsampledImage, maskPixelBuffer: maskPixelBuffer)
                
                let featurePrintRequest = VNGenerateImageFeaturePrintRequest()
                let maskedRequestHandler = VNImageRequestHandler(ciImage: maskedImage, options: [:])
                try maskedRequestHandler.perform([featurePrintRequest])
                
                guard let featurePrintObservation = featurePrintRequest.results?.first as? VNFeaturePrintObservation else { return }
                
                DispatchQueue.main.async {
                    if self.isRecording {
                        self.recordedFeaturePrints.append(featurePrintObservation)
                    }
                    if self.isDetecting {
                        self.compareFeatures(currentFeature: featurePrintObservation)
                    }
                }
            } catch {
                print("Error processing frame: \(error)")
            }
        }
    }

    private func applyMask(to image: CIImage, maskPixelBuffer: CVPixelBuffer) -> CIImage {
        let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)
        let invertFilter = CIFilter(name: "CIColorInvert")
        invertFilter?.setValue(maskImage, forKey: kCIInputImageKey)
        guard let invertedMaskImage = invertFilter?.outputImage else { return image }
        
        let maskedImage = image.applyingFilter("CIBlendWithMask", parameters: [
            "inputMaskImage": invertedMaskImage
        ])
        return maskedImage
    }
    
    private func downsampleCIImage(_ image: CIImage, scale: CGFloat = 0.5) -> CIImage {
        let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
        scaleFilter.setValue(image, forKey: kCIInputImageKey)
        scaleFilter.setValue(scale, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
        return scaleFilter.outputImage ?? image
    }

    private func compareFeatures(currentFeature: VNFeaturePrintObservation) {
        guard !referenceFeaturePrints.isEmpty else { return }
        
        var highestSimilarity: Float = 0.0
        for referenceFeature in referenceFeaturePrints {
            var distance: Float = 0.0
            do {
                try currentFeature.computeDistance(&distance, to: referenceFeature)
                let similarity = 1.0 / (1.0 + distance)
                if similarity > highestSimilarity {
                    highestSimilarity = similarity
                }
            } catch {
                print("Error comparing features: \(error)")
            }
        }
        
        recentScores.append(highestSimilarity)
        if recentScores.count > scoreBufferSize {
            recentScores.removeFirst()
        }
        let avgScore = recentScores.reduce(0, +) / Float(recentScores.count)
        self.matchingScore = avgScore
    }

    private func adjustImage(_ image: CIImage, brightness: Float, contrast: Float) -> CIImage {
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(contrast, forKey: kCIInputContrastKey)
        filter.setValue(brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(1.0, forKey: kCIInputSaturationKey)
        return filter.outputImage ?? image
    }
}
