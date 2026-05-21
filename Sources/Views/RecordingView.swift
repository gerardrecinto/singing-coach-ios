import SwiftUI

struct RecordingView: View {
    @ObservedObject var recorder: VocalRecorder
    let onFinish: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var error: AppError?

    var body: some View {
        NavigationStack {
            VStack(spacing: 44) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.15), lineWidth: 2)
                        .frame(width: 200, height: 200)

                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.indigo)
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 0.05), value: recorder.levelDB)

                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .onTapGesture { toggleRecording() }

                VStack(spacing: 6) {
                    Text(timeString(recorder.elapsedSeconds))
                        .font(.system(size: 52, design: .monospaced))
                        .foregroundStyle(recorder.isRecording ? .red : .primary)
                        .contentTransition(.numericText())

                    Text(recorder.isRecording ? "Tap to stop" : "Tap to start recording")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if recorder.isRecording {
                    levelMeter
                        .padding(.horizontal, 48)
                }

                Spacer()
            }
            .navigationTitle("Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        recorder.stop()
                        dismiss()
                    }
                }
            }
            .task { await checkPermission() }
            .alert(
                "Error",
                isPresented: .init(get: { error != nil }, set: { if !$0 { error = nil } })
            ) {
                Button("OK") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "")
            }
        }
    }

    private var pulseScale: CGFloat {
        guard recorder.isRecording else { return 1 }
        let normalized = Double(max(0, recorder.levelDB + 60)) / 60
        return 1.0 + CGFloat(normalized) * 0.25
    }

    private var levelMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                RoundedRectangle(cornerRadius: 4)
                    .fill(meterColor)
                    .frame(width: max(4, geo.size.width * meterFill))
                    .animation(.easeOut(duration: 0.04), value: recorder.levelDB)
            }
        }
        .frame(height: 8)
    }

    private var meterFill: CGFloat {
        CGFloat(max(0, Double(recorder.levelDB + 60)) / 60)
    }

    private var meterColor: Color {
        let fill = meterFill
        if fill > 0.85 { return .red }
        if fill > 0.65 { return .yellow }
        return .indigo
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stop()
            if let url = recorder.recordingURL {
                onFinish(url)
            }
        } else {
            do {
                try recorder.start()
            } catch {
                self.error = .recordingFailed(error.localizedDescription)
            }
        }
    }

    private func checkPermission() async {
        let granted = await recorder.requestPermission()
        if !granted { error = .microphonePermissionDenied }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
