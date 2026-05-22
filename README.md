# SingCoach

![iOS 16+](https://img.shields.io/badge/iOS-16%2B-000000?logo=apple&logoColor=white)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![Xcode 15](https://img.shields.io/badge/Xcode-15-1575F9?logo=xcode&logoColor=white)
![Claude](https://img.shields.io/badge/Claude-claude--sonnet--4--6-blueviolet)
![License: MIT](https://img.shields.io/badge/License-MIT-22c55e)

![Demo](docs/assets/demo.gif)

iOS vocal coaching app. Records a singing clip, runs on-device pitch and dynamics analysis, then sends the results to Claude for structured feedback — what's working, what to fix, and a 0–100 score.

## How it works

1. Tap **Record Now** and sing for at least 10 seconds.
2. The app analyzes the recording locally using the Accelerate framework (no audio ever leaves your device during analysis).
3. The analysis metrics are sent to Claude via the Anthropic API.
4. You get a score, two to three strengths, and three specific improvement steps.

## Tech stack

- **SwiftUI** — UI, fully declarative with `@Published` state driving all transitions
- **AVFoundation** — `AVAudioRecorder` for capture, `AVAudioFile` for offline read-back
- **Accelerate / vDSP** — normalized autocorrelation pitch detector (no third-party audio library), RMS dynamics, spectral centroid via in-place FFT
- **Anthropic API** — `claude-sonnet-4-6` for coaching feedback, structured JSON response

## Analysis pipeline

| Metric | Method |
|---|---|
| Pitch (Hz + note) | Normalized autocorrelation, Hann-windowed, 80–1100 Hz range |
| Pitch stability | `1 − σ/μ` over voiced frames |
| Voiced ratio | Fraction of frames above RMS threshold |
| Mean loudness | RMS → dB |
| Dynamic range | Peak vs. floor across 100ms chunks |
| Spectral centroid | Half-size real FFT via even/odd packing |

## Setup

**Requirements:** Xcode 15+, iOS 16+, an [Anthropic API key](https://console.anthropic.com).

**Build:**

```bash
# XcodeGen generates the .xcodeproj from project.yml
brew install xcodegen
xcodegen generate
open SingCoach.xcodeproj
```

**API key:** Go to **Settings** (gear icon) in the app and paste your `sk-ant-...` key. Stored in `UserDefaults` on-device, sent only to `api.anthropic.com`.

## Project layout

```
Sources/
├── App/
│   └── SingCoachApp.swift         @main entry point
├── Views/
│   ├── HomeView.swift             Record button, analysis trigger
│   ├── RecordingView.swift        Mic UI, level meter, timer
│   ├── ResultView.swift           Score gauge, strengths, improvements
│   └── SettingsView.swift         API key input
├── Services/
│   ├── VocalRecorder.swift        AVAudioRecorder wrapper, level metering
│   ├── VocalAnalyzer.swift        On-device pitch, dynamics, spectral analysis
│   └── ClaudeClient.swift         Anthropic API call, JSON response parsing
└── Models/
    └── Models.swift               VocalAnalysis, CoachingResult, AppError
SupportingFiles/
└── Info.plist
project.yml                        XcodeGen spec
```
