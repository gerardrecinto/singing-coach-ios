import Foundation

struct VocalAnalysis: Codable {
    let durationSeconds: Double
    let pitchHz: Double?
    let pitchStability: Double    // 0–1
    let voicedRatio: Double       // 0–1
    let meanLoudnessDB: Double
    let dynamicRangeDB: Double
    let spectralCentroidHz: Double
}

struct CoachingResult: Identifiable {
    let id = UUID()
    let score: Int
    let highlights: [String]
    let improvements: [String]
    let analysis: VocalAnalysis
}

enum AppError: LocalizedError {
    case microphonePermissionDenied
    case recordingFailed(String)
    case analysisFailed(String)
    case noAPIKey
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Enable it in Settings."
        case .recordingFailed(let msg):
            return "Recording failed: \(msg)"
        case .analysisFailed(let msg):
            return "Analysis failed: \(msg)"
        case .noAPIKey:
            return "Add your Anthropic API key in Settings first."
        case .networkError(let msg):
            return "Network error: \(msg)"
        }
    }
}
