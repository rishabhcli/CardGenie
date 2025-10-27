//
//  ImagePreprocessor.swift
//  CardGenie
//
//  Image preprocessing utilities for improving OCR accuracy.
//  Includes contrast enhancement, grayscale conversion, and de-skew operations.
//

import UIKit
import CoreImage
import Vision
import OSLog

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
