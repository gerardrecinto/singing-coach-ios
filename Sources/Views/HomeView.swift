import SwiftUI

struct HomeView: View {
    @StateObject private var recorder = VocalRecorder()
    @State private var showRecording  = false
    @State private var showSettings   = false
    @State private var result: CoachingResult?
    @State private var isAnalyzing    = false
    @State private var error: AppError?

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(.indigo)

                    Text("SingCoach")
                        .font(.largeTitle.bold())

                    Text("Record a clip. Get a score\nand your top improvement steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        showRecording = true
                    } label: {
                        Label("Record Now", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.indigo)
                    .disabled(isAnalyzing)

                    if isAnalyzing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Analyzing…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showRecording) {
            RecordingView(recorder: recorder) { url in
                showRecording = false
                Task { await analyzeRecording(url: url) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $result) { coaching in
            ResultView(result: coaching)
        }
        .alert(
            "Error",
            isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            Text(error?.localizedDescription ?? "")
        }
    }

    private func analyzeRecording(url: URL) async {
        guard !apiKey.isEmpty else { error = .noAPIKey; return }
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let analysis = try await VocalAnalyzer().analyze(url: url)
            let coaching = try await ClaudeClient(apiKey: apiKey).getCoaching(analysis)
            result = coaching
        } catch let e as AppError {
            error = e
        } catch {
            self.error = .analysisFailed(error.localizedDescription)
        }
    }
}
