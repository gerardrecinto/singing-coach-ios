import AVFoundation
import Accelerate

struct VocalAnalyzer {

    enum AnalyzerError: Error {
        case bufferAllocationFailed
        case noChannelData
        case fileTooShort
    }

    private static let frameSize = 2048
    private static let hopSize   = 512

    func analyze(url: URL) async throws -> VocalAnalysis {
        let file   = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let sr     = Float(format.sampleRate)
        let count  = AVAudioFrameCount(file.length)

        guard count > 0 else { throw AnalyzerError.fileTooShort }

        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
            throw AnalyzerError.bufferAllocationFailed
        }
        try file.read(into: buf)

        guard let ptr = buf.floatChannelData?[0] else {
            throw AnalyzerError.noChannelData
        }
        let samples  = Array(UnsafeBufferPointer(start: ptr, count: Int(count)))
        let duration = Double(count) / Double(sr)

        let pitch    = extractPitch(samples, sampleRate: sr)
        let loudness = rmsDB(samples)
        let dynRange = dynamicRange(samples, sampleRate: sr)
        let centroid = spectralCentroid(samples, sampleRate: sr)

        return VocalAnalysis(
            durationSeconds:    duration,
            pitchHz:            pitch.mean.map(Double.init),
            pitchStability:     pitch.stability,
            voicedRatio:        pitch.voicedRatio,
            meanLoudnessDB:     loudness,
            dynamicRangeDB:     dynRange,
            spectralCentroidHz: centroid
        )
    }

    // MARK: - Pitch (normalized autocorrelation, frame-by-frame)

    private func extractPitch(_ samples: [Float], sampleRate: Float)
        -> (mean: Float?, stability: Double, voicedRatio: Double)
    {
        var pitches: [Float] = []
        var total = 0
        var offset = 0

        while offset + Self.frameSize <= samples.count {
            total += 1
            if let f0 = f0(samples: samples, offset: offset, sr: sampleRate) {
                pitches.append(f0)
            }
            offset += Self.hopSize
        }

        guard !pitches.isEmpty else { return (nil, 0, 0) }

        var mean: Float = 0
        vDSP_meanv(pitches, 1, &mean, vDSP_Length(pitches.count))

        var diffs = pitches.map { $0 - mean }
        var sq    = [Float](repeating: 0, count: diffs.count)
        vDSP_vsq(diffs, 1, &sq, 1, vDSP_Length(sq.count))
        var variance: Float = 0
        vDSP_meanv(sq, 1, &variance, vDSP_Length(sq.count))

        let stability   = Double(max(0, 1.0 - sqrt(variance) / max(mean, 1)))
        let voicedRatio = Double(pitches.count) / Double(max(1, total))

        return (mean, stability, voicedRatio)
    }

    private func f0(samples: [Float], offset: Int, sr: Float) -> Float? {
        let n = Self.frameSize
        var win = Array(samples[offset ..< offset + n])

        var hann = [Float](repeating: 0, count: n)
        vDSP_hann_window(&hann, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(win, 1, hann, 1, &win, 1, vDSP_Length(n))

        var rms: Float = 0
        vDSP_rmsqv(win, 1, &rms, vDSP_Length(n))
        guard rms > 5e-4 else { return nil }

        var r0: Float = 0
        vDSP_dotpr(win, 1, win, 1, &r0, vDSP_Length(n))
        guard r0 > 1e-8 else { return nil }

        let minLag = max(1, Int(sr / 1100))
        let maxLag = min(n / 2, Int(sr / 80))
        guard minLag < maxLag else { return nil }

        var bestCorr: Float = 0
        var bestLag  = 0

        win.withUnsafeBufferPointer { ptr in
            let base = ptr.baseAddress!
            for lag in minLag ... maxLag {
                var r: Float = 0
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &r, vDSP_Length(n - lag))
                let norm = r / r0
                if norm > bestCorr { bestCorr = norm; bestLag = lag }
            }
        }

        guard bestCorr > 0.45, bestLag > 0 else { return nil }
        return sr / Float(bestLag)
    }

    // MARK: - Dynamics

    private func rmsDB(_ samples: [Float]) -> Double {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms > 1e-10 ? Double(20 * log10(rms)) : -96
    }

    private func dynamicRange(_ samples: [Float], sampleRate: Float) -> Double {
        let chunk = max(1, Int(sampleRate * 0.1))
        var vals: [Float] = []

        var i = 0
        while i + chunk <= samples.count {
            var rms: Float = 0
            let slice = Array(samples[i ..< i + chunk])
            vDSP_rmsqv(slice, 1, &rms, vDSP_Length(chunk))
            if rms > 1e-6 { vals.append(20 * log10(rms)) }
            i += chunk
        }

        guard vals.count > 1 else { return 0 }
        var hi: Float = 0, lo: Float = 0
        vDSP_maxv(vals, 1, &hi, vDSP_Length(vals.count))
        vDSP_minv(vals, 1, &lo, vDSP_Length(vals.count))
        return Double(hi - lo)
    }

    // MARK: - Spectral centroid (half-size FFT via even/odd packing)

    private func spectralCentroid(_ samples: [Float], sampleRate: Float) -> Double {
        let n = min(samples.count, 4096)
        var p = 1
        while (1 << p) < n { p += 1 }
        let fftN  = 1 << p
        let halfN = fftN / 2

        guard let setup = vDSP_create_fftsetup(vDSP_Length(p), FFTRadix(kFFTRadix2)) else { return 1000 }
        defer { vDSP_destroy_fftsetup(setup) }

        var re = [Float](repeating: 0, count: halfN)
        var im = [Float](repeating: 0, count: halfN)
        for k in 0 ..< halfN {
            re[k] = 2 * k     < samples.count ? samples[2 * k]     : 0
            im[k] = 2 * k + 1 < samples.count ? samples[2 * k + 1] : 0
        }

        re.withUnsafeMutableBufferPointer { rPtr in
            im.withUnsafeMutableBufferPointer { iPtr in
                var split = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, vDSP_Length(p), FFTDirection(kFFTDirection_Forward))
            }
        }

        var mags = [Float](repeating: 0, count: halfN)
        re.withUnsafeBufferPointer { rPtr in
            im.withUnsafeBufferPointer { iPtr in
                var split = DSPSplitComplex(
                    realp: UnsafeMutablePointer(mutating: rPtr.baseAddress!),
                    imagp: UnsafeMutablePointer(mutating: iPtr.baseAddress!)
                )
                vDSP_zvabs(&split, 1, &mags, 1, vDSP_Length(halfN))
            }
        }

        let binHz = Double(sampleRate) / Double(fftN)
        var wSum = 0.0, total = 0.0
        for k in 0 ..< halfN {
            let mag = Double(mags[k])
            wSum += Double(k) * binHz * mag
            total += mag
        }
        return total > 0 ? wSum / total : 1000
    }
}
