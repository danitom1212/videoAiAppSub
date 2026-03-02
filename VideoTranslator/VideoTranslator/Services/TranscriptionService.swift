import Foundation
import AVFoundation
import Speech

protocol TranscriptionServiceDelegate: AnyObject {
    func transcriptionDidStart()
    func transcriptionDidComplete(with subtitles: [Subtitle])
    func transcriptionDidFail(with error: Error)
}

class TranscriptionService {
    
    // MARK: - Properties
    weak var delegate: TranscriptionServiceDelegate?
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    init() {
        // Default to US English recognizer
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    }
    
    // MARK: - Public Methods
    func transcribeAudio(from url: URL) {
        delegate?.transcriptionDidStart()
        
        // Check speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.performTranscription(from: url)
                case .denied, .restricted:
                    self.delegate?.transcriptionDidFail(with: TranscriptionError.notAuthorized)
                case .notDetermined:
                    self.delegate?.transcriptionDidFail(with: TranscriptionError.notDetermined)
                @unknown default:
                    self.delegate?.transcriptionDidFail(with: TranscriptionError.unknown)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func performTranscription(from url: URL) {
        // Extract audio from video
        extractAudioFromVideo(url: url) { [weak self] result in
            switch result {
            case .success(let audioURL):
                self?.transcribeAudioFile(audioURL)
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.delegate?.transcriptionDidFail(with: error)
                }
            }
        }
    }
    
    private func extractAudioFromVideo(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: url)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(TranscriptionError.audioExtractionFailed))
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("extracted_audio.m4a")
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed:
                    completion(.failure(exportSession.error ?? TranscriptionError.audioExtractionFailed))
                case .cancelled:
                    completion(.failure(TranscriptionError.cancelled))
                default:
                    completion(.failure(TranscriptionError.unknown))
                }
            }
        }
    }
    
    private func transcribeAudioFile(_ audioURL: URL) {
        let asset = AVAsset(url: audioURL)
        
        // Create a reader for the audio file
        guard let reader = try? AVAssetReader(asset: asset) else {
            delegate?.transcriptionDidFail(with: TranscriptionError.audioReaderFailed)
            return
        }
        
        guard let track = asset.tracks(withMediaType: .audio).first else {
            delegate?.transcriptionDidFail(with: TranscriptionError.noAudioTrack)
            return
        }
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false
        ])
        
        reader.add(output)
        reader.startReading()
        
        // Process audio in chunks and transcribe
        processAudioInChunks(reader: reader, output: output)
    }
    
    private func processAudioInChunks(reader: AVAssetReader, output: AVAssetReaderTrackOutput) {
        var subtitles: [Subtitle] = []
        var currentTime: TimeInterval = 0
        let chunkDuration: TimeInterval = 10.0 // Process 10-second chunks
        
        while reader.status == .reading {
            autoreleasepool {
                var audioSamples: [CMSampleBuffer] = []
                var chunkEndTime = currentTime + chunkDuration
                
                // Collect samples for this chunk
                while reader.status == .reading && currentTime < chunkEndTime {
                    if let sampleBuffer = output.copyNextSampleBuffer() {
                        audioSamples.append(sampleBuffer)
                        currentTime = CMTimeGetSeconds(sampleBuffer.presentationTimeStamp)
                    } else {
                        break
                    }
                }
                
                // Transcribe this chunk
                if !audioSamples.isEmpty {
                    transcribeAudioChunk(audioSamples, startTime: currentTime - chunkDuration) { chunkSubtitles in
                        subtitles.append(contentsOf: chunkSubtitles)
                    }
                }
            }
        }
        
        // Handle completion
        DispatchQueue.main.async { [weak self] in
            if reader.status == .completed {
                self?.delegate?.transcriptionDidComplete(with: subtitles)
            } else if let error = reader.error {
                self?.delegate?.transcriptionDidFail(with: error)
            }
        }
    }
    
    private func transcribeAudioChunk(_ samples: [CMSampleBuffer], startTime: TimeInterval, completion: @escaping ([Subtitle]) -> Void) {
        // For now, we'll use a simplified approach
        // In a production app, you might want to use a more sophisticated speech recognition service
        // like OpenAI's Whisper API or Google Cloud Speech-to-Text
        
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        
        let recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var chunkSubtitles: [Subtitle] = []
            
            if let result = result {
                let segments = result.bestTranscription.segments
                
                for segment in segments {
                    let subtitle = Subtitle(
                        startTime: startTime + segment.timestamp.startSeconds,
                        endTime: startTime + segment.timestamp.endSeconds,
                        originalText: segment.substring,
                        confidence: segment.confidence
                    )
                    chunkSubtitles.append(subtitle)
                }
            }
            
            if error != nil || result?.isFinal == true {
                completion(chunkSubtitles)
            }
        }
        
        // Add audio samples to the recognition request
        for sampleBuffer in samples {
            // Convert CMSampleBuffer to AVAudioPCMBuffer if needed
            // For now, we'll skip this conversion as it requires additional audio processing
            print("Processing audio sample")
        }
        
        recognitionRequest.endAudio()
    }
}

// MARK: - TranscriptionError
enum TranscriptionError: LocalizedError {
    case notAuthorized
    case notDetermined
    case audioExtractionFailed
    case audioReaderFailed
    case noAudioTrack
    case cancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .notDetermined:
            return "Speech recognition authorization is not determined."
        case .audioExtractionFailed:
            return "Failed to extract audio from video."
        case .audioReaderFailed:
            return "Failed to read audio data."
        case .noAudioTrack:
            return "No audio track found in the video."
        case .cancelled:
            return "Transcription was cancelled."
        case .unknown:
            return "An unknown error occurred during transcription."
        }
    }
}
