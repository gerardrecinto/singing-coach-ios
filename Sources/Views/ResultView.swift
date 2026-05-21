import SwiftUI

struct ResultView: View {
    let result: CoachingResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    scoreGauge
                    statsRow
                    if !result.highlights.isEmpty {
                        itemCard(
                            title: "What's Working",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            items: result.highlights
                        )
                    }
                    if !result.improvements.isEmpty {
                        itemCard(
                            title: "Top Improvements",
                            icon: "arrow.up.circle.fill",
                            color: .indigo,
                            items: result.improvements
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Your Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scoreGauge: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * CGFloat(result.score) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
                .animation(.spring(duration: 0.9), value: result.score)

            VStack(spacing: 2) {
                Text("\(result.score)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("/ 100")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 210, height: 210)
        .padding(.top, 8)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statPill(label: "Duration", value: String(format: "%.0fs", result.analysis.durationSeconds))

            if let hz = result.analysis.pitchHz {
                statPill(label: "Pitch", value: String(format: "%.0f Hz", hz))
            }

            statPill(
                label: "Stability",
                value: String(format: "%.0f%%", result.analysis.pitchStability * 100)
            )
        }
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func itemCard(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(idx + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(color, in: Circle())
                    Text(item)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        switch result.score {
        case 80...100: return .green
        case 60...79:  return .yellow
        default:       return .orange
        }
    }
}
