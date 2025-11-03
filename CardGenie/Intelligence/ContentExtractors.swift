//
//  ContentExtractors.swift
//  CardGenie
//
//  Content extraction from various sources: vision (OCR), speech, and image preprocessing.
//

import Foundation
import Vision
import Speech
import UIKit
import AVFoundation
import Combine
import OSLog
import VisionKit

// MARK: - VisionTextExtractor


/// Result of text extraction with metadata
struct TextExtractionResult {
    let text: String
    let confidence: Double
    let detectedLanguages: [String]
    let blockCount: Int
    let characterCount: Int
    let preprocessingApplied: Bool

    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.9...1.0: return .high
        case 0.7..<0.9: return .medium
        case 0.5..<0.7: return .low
        default: return .veryLow
        }
    }
}

enum ConfidenceLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case veryLow = "Very Low"

    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "orange"
        case .veryLow: return "red"
        }
    }
}

/// Text extraction from images using Apple's Vision framework
@MainActor
final class VisionTextExtractor: ObservableObject {
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "Vision")
    private let preprocessor = ImagePreprocessor()

    @Published var extractedText = ""
    @Published var isProcessing = false
    @Published var error: VisionError?
    @Published var lastExtractionResult: TextExtractionResult?

    /// Extract text from an image using Vision framework with preprocessing
    /// - Parameters:
    ///   - image: The UIImage to extract text from
    ///   - enablePreprocessing: Whether to apply image preprocessing
    /// - Returns: Extracted text as a single string
    /// - Throws: VisionError if extraction fails
    func extractText(from image: UIImage, enablePreprocessing: Bool = true) async throws -> String {
        let result = try await extractTextWithMetadata(from: image, enablePreprocessing: enablePreprocessing)
        return result.text
    }

    /// Extract text from an image with full metadata
    /// - Parameters:
    ///   - image: The UIImage to extract text from
    ///   - enablePreprocessing: Whether to apply image preprocessing
    /// - Returns: TextExtractionResult with confidence and language info
    /// - Throws: VisionError if extraction fails
    func extractTextWithMetadata(from image: UIImage, enablePreprocessing: Bool = true) async throws -> TextExtractionResult {
        isProcessing = true
        error = nil
        defer { isProcessing = false }

        // Preprocess image if enabled
        var processedImage = image
        var preprocessingApplied = false

        if enablePreprocessing {
            let config = preprocessor.recommendPreprocessing(for: image)
            let preprocessResult = preprocessor.preprocess(image, config: config)
            processedImage = preprocessResult.processedImage
            preprocessingApplied = !preprocessResult.appliedOperations.isEmpty

            if preprocessingApplied {
                logger.info("Applied preprocessing: \(preprocessResult.appliedOperations.joined(separator: ", "))")
                ScanAnalytics.shared.trackPreprocessing()
            }
        }

        guard let cgImage = processedImage.cgImage else {
            logger.error("Invalid image - no CGImage representation")
            let visionError = VisionError.invalidImage
            error = visionError
            throw visionError
        }

        logger.info("Starting text recognition...")

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    self.logger.error("Vision request failed: \(error.localizedDescription)")
                    let visionError = VisionError.processingFailed(error.localizedDescription)
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self.logger.warning("No text observations found")
                    let visionError = VisionError.noTextFound
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                if observations.isEmpty {
                    self.logger.warning("Text observations array is empty")
                    let visionError = VisionError.noTextFound
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                // Extract text and confidence from observations
                var allText: [String] = []
                var totalConfidence: Float = 0
                let detectedLanguages = Set<String>()

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    allText.append(candidate.string)
                    totalConfidence += candidate.confidence

                    // Track detected languages if available
                    // Note: Language detection would require additional processing
                }

                let recognizedText = allText.joined(separator: "\n")

                if recognizedText.isEmpty {
                    self.logger.warning("Recognized text is empty")
                    let visionError = VisionError.noTextFound
                    self.error = visionError
                    continuation.resume(throwing: visionError)
                    return
                }

                let averageConfidence = Double(totalConfidence) / Double(observations.count)
                let result = TextExtractionResult(
                    text: recognizedText,
                    confidence: averageConfidence,
                    detectedLanguages: Array(detectedLanguages),
                    blockCount: observations.count,
                    characterCount: recognizedText.count,
                    preprocessingApplied: preprocessingApplied
                )

                self.logger.info("Extracted \(recognizedText.count) characters with confidence \(String(format: "%.2f", averageConfidence))")
                self.extractedText = recognizedText
                self.lastExtractionResult = result
                continuation.resume(returning: result)
            }

            // Configure for maximum accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Support multiple languages if needed
            request.recognitionLanguages = ["en-US"]

            // Automatic language detection
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                self.logger.error("Failed to perform Vision request: \(error.localizedDescription)")
                let visionError = VisionError.processingFailed(error.localizedDescription)
                self.error = visionError
                continuation.resume(throwing: visionError)
            }
        }
    }

    /// Check if VisionKit document scanning is available
    func isDocumentScanningAvailable() -> Bool {
        return VNDocumentCameraViewController.isSupported
    }
}

// MARK: - Vision Error Types

enum VisionError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed(String)
    case notSupported

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The image could not be processed. Please try a different image."
        case .noTextFound:
            return "No text was found in the image. Make sure the image contains readable text."
        case .processingFailed(let reason):
            return "Text extraction failed: \(reason)"
        case .notSupported:
            return "Document scanning is not supported on this device."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidImage:
            return "Try taking a new photo or choosing a different image."
        case .noTextFound:
            return "Ensure the image is clear, well-lit, and contains visible text."
        case .processingFailed:
            return "Please try again. If the problem persists, restart the app."
        case .notSupported:
            return "Photo scanning requires iOS 16 or later."
        }
    }
}

// MARK: - SpeechToTextConverter


/// Speech recognition and audio recording engine
@MainActor
final class SpeechToTextConverter: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "Speech")

    // Published state
    @Published var transcribedText = ""
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var error: SpeechError?
    @Published var recordingDuration: TimeInterval = 0

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // Audio recording
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var recordingTimerTask: Task<Void, Never>?

    // MARK: - Authorization

    /// Check and request speech recognition authorization
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let authorized = status == .authorized
                if !authorized {
                    self.logger.warning("Speech recognition not authorized: \(String(describing: status))")
                }
                continuation.resume(returning: authorized)
            }
        }
    }

    /// Check current authorization status
    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        return SFSpeechRecognizer.authorizationStatus()
    }

    /// Check if speech recognition is available
    func isAvailable() -> Bool {
        guard let recognizer = speechRecognizer else {
            logger.warning("Speech recognizer is nil")
            return false
        }
        return recognizer.isAvailable
    }

    // MARK: - Recording

    /// Start recording audio and transcribing in real-time
    func startRecording() async throws {
        // Check authorization
        guard authorizationStatus() == .authorized else {
            logger.error("Speech recognition not authorized")
            throw SpeechError.notAuthorized
        }

        if #available(iOS 13.0, *), let recognizer = speechRecognizer, !recognizer.supportsOnDeviceRecognition {
            logger.error("On-device recognition not supported on this device")
            throw SpeechError.onDeviceNotSupported
        }

        guard isAvailable() else {
            logger.error("Speech recognizer not available")
            throw SpeechError.recognizerUnavailable
        }

        // Cancel any ongoing tasks
        if recognitionTask != nil {
            stopRecording()
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Setup recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("recording-\(UUID().uuidString).m4a")

        // Setup audio recorder for saving
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        if let url = recordingURL {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.unableToCreateRequest
        }

        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }

        // Update state
        isRecording = true
        recordingDuration = 0

        // Start duration timer
        recordingTimerTask?.cancel()
        recordingTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch {
                    return
                }
                await MainActor.run {
                    guard let self else { return }
                    self.recordingDuration += 0.1
                }
            }
        }

        logger.info("Recording started")
    }

    /// Stop recording and finalize transcription
    func stopRecording() {
        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Stop audio recorder
        audioRecorder?.stop()

        // Cancel recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        // Stop timer
        recordingTimerTask?.cancel()
        recordingTimerTask = nil

        // Update state
        isRecording = false

        logger.info("Recording stopped. Duration: \(self.recordingDuration)s")
    }

    /// Get the URL of the saved audio recording
    func getSavedRecordingURL() -> URL? {
        return recordingURL
    }

    /// Delete the saved recording
    func deleteSavedRecording() {
        guard let url = recordingURL else { return }

        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Deleted recording at \(url)")
        } catch {
            logger.error("Failed to delete recording: \(error.localizedDescription)")
        }

        recordingURL = nil
    }

    // MARK: - Offline Transcription

    /// Transcribe a pre-recorded audio file
    func transcribeAudioFile(_ url: URL) async throws -> String {
        guard authorizationStatus() == .authorized else {
            throw SpeechError.notAuthorized
        }

        guard isAvailable() else {
            throw SpeechError.recognizerUnavailable
        }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Starting transcription of audio file")

        return try await withCheckedThrowingContinuation { continuation in
        let request = SFSpeechURLRecognitionRequest(url: url)
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = true
        }
        request.shouldReportPartialResults = false

            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    self.logger.error("Transcription failed: \(error.localizedDescription)")
                    continuation.resume(throwing: SpeechError.transcriptionFailed(error.localizedDescription))
                    return
                }

                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    self.logger.info("Transcription completed: \(text.count) characters")
                    continuation.resume(returning: text)
                }
            }
        }
    }
}

// MARK: - Speech Error Types

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case unableToCreateRequest
    case transcriptionFailed(String)
    case audioEngineError
    case onDeviceNotSupported

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone access is required to record lectures. Please enable it in Settings."
        case .recognizerUnavailable:
            return "Speech recognition is not available on this device or for this language."
        case .unableToCreateRequest:
            return "Unable to start speech recognition. Please try again."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .audioEngineError:
            return "Audio recording error. Please check your microphone."
        case .onDeviceNotSupported:
            return "This device doesn’t support on-device speech recognition required for offline transcription."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthorized:
            return "Go to Settings > Privacy & Security > Microphone and enable access for CardGenie."
        case .recognizerUnavailable:
            return "Make sure you have an internet connection for the first transcription, then it will work offline."
        case .unableToCreateRequest:
            return "Restart the app and try again."
        case .transcriptionFailed:
            return "Make sure you're speaking clearly in a quiet environment."
        case .audioEngineError:
            return "Check that your microphone is working and not being used by another app."
        case .onDeviceNotSupported:
            return "Use a device that supports on-device speech recognition or connect to a newer Apple Intelligence-compatible device."
        }
    }
}

// MARK: - ImagePreprocessor


/// Configuration for image preprocessing
struct PreprocessingConfig {
    var enhanceContrast: Bool = true
    var convertToGrayscale: Bool = true
    var sharpen: Bool = true
    var autoRotate: Bool = true
    var denoise: Bool = false

    static let standard = PreprocessingConfig()
    static let minimal = PreprocessingConfig(enhanceContrast: true, convertToGrayscale: false, sharpen: false, autoRotate: true, denoise: false)
    static let aggressive = PreprocessingConfig(enhanceContrast: true, convertToGrayscale: true, sharpen: true, autoRotate: true, denoise: true)
}

/// Result of preprocessing operation
struct PreprocessingResult {
    let processedImage: UIImage
    let appliedOperations: [String]
    let processingTime: TimeInterval
}

/// Image preprocessing for OCR quality improvement
final class ImagePreprocessor {
    private let logger = Logger(subsystem: "com.cardgenie.app", category: "ImagePreprocessor")
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Preprocess an image to improve OCR accuracy
    /// - Parameters:
    ///   - image: The input image to preprocess
    ///   - config: Preprocessing configuration
    /// - Returns: Preprocessing result with enhanced image
    func preprocess(_ image: UIImage, config: PreprocessingConfig = .standard) -> PreprocessingResult {
        let startTime = Date()
        var appliedOps: [String] = []
        var currentImage = image

        logger.info("Starting image preprocessing with config: \(String(describing: config))")

        // Convert to CIImage for processing
        guard var ciImage = CIImage(image: image) else {
            logger.warning("Failed to create CIImage, returning original")
            return PreprocessingResult(
                processedImage: image,
                appliedOperations: [],
                processingTime: Date().timeIntervalSince(startTime)
            )
        }

        // 1. Auto-rotation based on text detection
        if config.autoRotate {
            if let rotated = autoRotate(ciImage) {
                ciImage = rotated
                appliedOps.append("auto-rotate")
                logger.info("Applied auto-rotation")
            }
        }

        // 2. Convert to grayscale
        if config.convertToGrayscale {
            ciImage = convertToGrayscale(ciImage)
            appliedOps.append("grayscale")
            logger.info("Converted to grayscale")
        }

        // 3. Enhance contrast
        if config.enhanceContrast {
            ciImage = enhanceContrast(ciImage)
            appliedOps.append("contrast")
            logger.info("Enhanced contrast")
        }

        // 4. Sharpen
        if config.sharpen {
            ciImage = sharpen(ciImage)
            appliedOps.append("sharpen")
            logger.info("Applied sharpening")
        }

        // 5. Denoise (optional, can be slow)
        if config.denoise {
            ciImage = denoise(ciImage)
            appliedOps.append("denoise")
            logger.info("Applied denoising")
        }

        // Convert back to UIImage
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            currentImage = UIImage(cgImage: cgImage)
        } else {
            logger.warning("Failed to create CGImage, returning original")
            return PreprocessingResult(
                processedImage: image,
                appliedOperations: [],
                processingTime: Date().timeIntervalSince(startTime)
            )
        }

        let duration = Date().timeIntervalSince(startTime)
        logger.info("Preprocessing completed in \(String(format: "%.2f", duration))s")

        return PreprocessingResult(
            processedImage: currentImage,
            appliedOperations: appliedOps,
            processingTime: duration
        )
    }

    // MARK: - Processing Operations

    private func convertToGrayscale(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CIPhotoEffectNoir")
        filter?.setValue(image, forKey: kCIInputImageKey)
        return filter?.outputImage ?? image
    }

    private func enhanceContrast(_ image: CIImage) -> CIImage {
        // Use adaptive tone mapping for better contrast
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(1.3, forKey: kCIInputContrastKey) // Increase contrast by 30%
        filter?.setValue(1.1, forKey: kCIInputBrightnessKey) // Slight brightness boost
        return filter?.outputImage ?? image
    }

    private func sharpen(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CISharpenLuminance")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(0.7, forKey: kCIInputSharpnessKey) // Moderate sharpening
        return filter?.outputImage ?? image
    }

    private func denoise(_ image: CIImage) -> CIImage {
        let filter = CIFilter(name: "CINoiseReduction")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(0.02, forKey: "inputNoiseLevel")
        filter?.setValue(0.4, forKey: "inputSharpness")
        return filter?.outputImage ?? image
    }

    private func autoRotate(_ image: CIImage) -> CIImage? {
        // Use Vision to detect text orientation
        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = false

        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        try? handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            logger.info("No text detected for auto-rotation")
            return nil
        }

        // Calculate average angle of text regions
        var totalAngle: CGFloat = 0
        var count = 0

        for observation in observations {
            // Get the bounding box
            let box = observation.boundingBox
            // Calculate angle (simplified - would need more complex logic for accurate rotation)
            totalAngle += box.width > box.height ? 0 : 90
            count += 1
        }

        guard count > 0 else { return nil }
        let averageAngle = totalAngle / CGFloat(count)

        // Only rotate if there's significant skew
        if abs(averageAngle) > 5 && abs(averageAngle) < 85 {
            let radians = -averageAngle * .pi / 180
            return image.transformed(by: CGAffineTransform(rotationAngle: radians))
        }

        return nil
    }

    /// Quick check if preprocessing would likely help
    /// - Parameter image: The image to analyze
    /// - Returns: Recommendation for preprocessing level
    func recommendPreprocessing(for image: UIImage) -> PreprocessingConfig {
        guard let ciImage = CIImage(image: image) else {
            return .minimal
        }

        // Analyze image characteristics
        let brightness = averageBrightness(ciImage)
        let contrast = estimateContrast(ciImage)

        logger.info("Image analysis - brightness: \(String(format: "%.2f", brightness)), contrast: \(String(format: "%.2f", contrast))")

        // Recommend based on characteristics
        if brightness < 0.3 || brightness > 0.8 || contrast < 0.4 {
            logger.info("Recommending aggressive preprocessing")
            return .aggressive
        } else if brightness < 0.4 || brightness > 0.7 || contrast < 0.6 {
            logger.info("Recommending standard preprocessing")
            return .standard
        } else {
            logger.info("Recommending minimal preprocessing")
            return .minimal
        }
    }

    private func averageBrightness(_ image: CIImage) -> CGFloat {
        let extentVector = CIVector(x: image.extent.origin.x, y: image.extent.origin.y, z: image.extent.size.width, w: image.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: image, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else {
            return 0.5
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return CGFloat(bitmap[0]) / 255.0
    }

    private func estimateContrast(_ image: CIImage) -> CGFloat {
        // Simple contrast estimation using standard deviation of brightness
        // A more accurate implementation would analyze the histogram
        return 0.5 // Placeholder - would need full histogram analysis
    }
}
