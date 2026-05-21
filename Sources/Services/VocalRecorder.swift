import AVFoundation

@MainActor
final class VocalRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var levelDB: Float = -60
    @Published var elapsedSeconds: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var startDate: Date?
    private(set) var recordingURL: URL?

    private static var outputURL: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("singcoach_session.caf")
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
        try session.setActive(true)

        let url = Self.outputURL
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatAppleLossless,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.isMeteringEnabled = true
        rec.record()

        recorder = rec
        recordingURL = url
        isRecording = true
        startDate = Date()

        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        levelTimer?.invalidate()
        levelTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func tick() {
        recorder?.updateMeters()
        levelDB = recorder?.averagePower(forChannel: 0) ?? -60
        elapsedSeconds = Date().timeIntervalSince(startDate ?? Date())
    }
}
