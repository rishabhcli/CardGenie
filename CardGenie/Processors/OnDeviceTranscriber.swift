//
//  OnDeviceTranscriber.swift
//  CardGenie
//
//  Streaming wrapper around SFSpeechRecognizer for offline transcription.
//

import Foundation
import AVFoundation
import Speech

protocol OnDeviceTranscriberDelegate: AnyObject {
    @MainActor
    func transcriber(_ transcriber: OnDeviceTranscriber, didReceive result: SFSpeechRecognitionResult, isFinal: Bool)

    @MainActor
    func transcriber(_ transcriber: OnDeviceTranscriber, didFail error: OnDeviceTranscriberError)
}

enum OnDeviceTranscriberError: LocalizedError {
    case unavailable
    case notAuthorized
    case unsupportedLocale
    case failed(Error)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Speech recognizer is unavailable."
        case .notAuthorized:
            return "Speech recognition is not authorized."
        case .unsupportedLocale:
            return "On-device recognition is not supported for this locale."
        case .failed(let error):
            return error.localizedDescription
        }
    }
}

final class OnDeviceTranscriber {
    weak var delegate: OnDeviceTranscriberDelegate?

    private let locale: Locale
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    func prepareAuthorization() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        return status == .authorized
    }

    func startStreaming() throws {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw OnDeviceTranscriberError.notAuthorized
        }

        guard let speechRecognizer else {
            throw OnDeviceTranscriberError.unavailable
        }

        if #available(iOS 13.0, *), !speechRecognizer.supportsOnDeviceRecognition {
            throw OnDeviceTranscriberError.unsupportedLocale
        }

        cancelRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = true
        }
        request.shouldReportPartialResults = true

        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let error {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.delegate?.transcriber(self, didFail: .failed(error))
                }
                self.cancelRecognition()
                return
            }

            guard let result else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.transcriber(self, didReceive: result, isFinal: result.isFinal)
            }

            if result.isFinal {
                self.cancelRecognition()
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stop() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        cancelRecognition()
    }

    private func cancelRecognition() {
        recognitionRequest = nil
        recognitionTask = nil
    }
}
