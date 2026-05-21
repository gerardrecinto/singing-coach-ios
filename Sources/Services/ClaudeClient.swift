import Foundation

struct ClaudeClient {
    let apiKey: String

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func getCoaching(_ analysis: VocalAnalysis) async throws -> CoachingResult {
        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 512,
            "system": "You are a vocal coach. Respond ONLY with valid JSON and no markdown fences.",
            "messages": [["role": "user", "content": buildPrompt(analysis)]],
        ]

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            throw AppError.networkError("HTTP \(code)")
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first?.text else {
            throw AppError.networkError("Empty response from API")
        }

        return parseCoaching(text, analysis: analysis)
    }

    private func buildPrompt(_ a: VocalAnalysis) -> String {
        var lines = [
            "Analyze this vocal performance and score it.",
            "Duration: \(String(format: "%.1f", a.durationSeconds))s",
        ]

        if let hz = a.pitchHz {
            lines += [
                "Mean pitch: \(String(format: "%.0f", hz)) Hz",
                "Pitch stability: \(String(format: "%.0f", a.pitchStability * 100))%",
                "Voiced frames: \(String(format: "%.0f", a.voicedRatio * 100))%",
            ]
        } else {
            lines.append("Pitch: no clear pitch detected")
        }

        lines += [
            "Mean volume: \(String(format: "%.1f", a.meanLoudnessDB)) dB",
            "Dynamic range: \(String(format: "%.1f", a.dynamicRangeDB)) dB",
            "Spectral centroid: \(String(format: "%.0f", a.spectralCentroidHz)) Hz",
            "",
            "Return exactly this JSON (no other text):",
            "{",
            "  \"score\": <0-100>,",
            "  \"highlights\": [\"<strength>\", \"<strength>\"],",
            "  \"improvements\": [\"<fix 1>\", \"<fix 2>\", \"<fix 3>\"]",
            "}",
        ]

        return lines.joined(separator: "\n")
    }

    private func parseCoaching(_ text: String, analysis: VocalAnalysis) -> CoachingResult {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        if let data = cleaned.data(using: .utf8),
           let json = try? JSONDecoder().decode(CoachingJSON.self, from: data)
        {
            return CoachingResult(
                score: max(0, min(100, json.score)),
                highlights: json.highlights,
                improvements: json.improvements,
                analysis: analysis
            )
        }

        return CoachingResult(
            score: 50,
            highlights: ["Recording captured successfully."],
            improvements: [
                "Record a longer clip (10+ seconds) for fuller analysis.",
                "Sing a scale to help the pitch detector track your voice.",
                "Focus on steady breath support throughout each phrase.",
            ],
            analysis: analysis
        )
    }
}

private struct CoachingJSON: Decodable {
    let score: Int
    let highlights: [String]
    let improvements: [String]
}

private struct AnthropicResponse: Decodable {
    struct Content: Decodable { let text: String }
    let content: [Content]
}
