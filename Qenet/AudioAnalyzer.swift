import AVFoundation
import Accelerate
import Observation

/// Analyzes live audio from the microphone to identify Ethiopian pentatonic scales.
@Observable
final class AudioAnalyzer {
    
    // MARK: - Published State
    
    private(set) var isListening = false
    private(set) var detectedScale: EthiopianScale?
    private(set) var confidence: Double = 0
    private(set) var detectedRootName: String = ""
    private(set) var detectedSemitones: Set<Int> = []
    private(set) var dominantFrequency: Double = 0
    private(set) var inputLevel: Float = 0
    
    // MARK: - Private
    
    private var audioEngine: AVAudioEngine?
    private let bufferSize: AVAudioFrameCount = 4096
    private var sampleRate: Double = 44100
    private var semitoneHistogram = [Int: Int]()
    private var recentDetections: [(semitone: Int, timestamp: Date)] = []
    private let windowDuration: TimeInterval = 4.0
    private let minDistinctNotes = 3
    
    // FFT resources
    private let fftN = 4096
    private let log2n: vDSP_Length = 12
    private var fftSetup: FFTSetup?
    private var fftWindow = [Float](repeating: 0, count: 4096)
    
    init() {
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        vDSP_hann_window(&fftWindow, vDSP_Length(fftN), Int32(vDSP_HANN_NORM))
    }
    
    // MARK: - Lifecycle
    
    func startListening() {
        guard !isListening else { return }
        reset()
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }
        
        do {
            try engine.start()
            isListening = true
        } catch {
            print("AudioAnalyzer: Failed to start: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isListening = false
    }
    
    func reset() {
        detectedScale = nil
        confidence = 0
        detectedRootName = ""
        detectedSemitones = []
        dominantFrequency = 0
        inputLevel = 0
        semitoneHistogram.removeAll()
        recentDetections.removeAll()
    }
    
    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
        stopListening()
    }
    
    // MARK: - Audio Processing
    
    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // RMS level
        var rms: Float = 0
        vDSP_measqv(channelData, 1, &rms, vDSP_Length(frameCount))
        let level = sqrt(rms)
        
        guard level > 0.01 else {
            DispatchQueue.main.async { self.inputLevel = level }
            return
        }
        
        guard let freq = detectPitch(channelData, frameCount: frameCount) else {
            DispatchQueue.main.async { self.inputLevel = level }
            return
        }
        
        let semitone = frequencyToSemitone(freq)
        
        DispatchQueue.main.async {
            self.inputLevel = level
            self.dominantFrequency = freq
            self.addDetection(semitone: semitone)
            self.updateScaleIdentification()
        }
    }
    
    // MARK: - Pitch Detection
    
    private func detectPitch(_ data: UnsafePointer<Float>, frameCount: Int) -> Double? {
        guard frameCount >= fftN, let setup = fftSetup else { return nil }
        
        let halfN = fftN / 2
        
        // Window the input
        var windowed = [Float](repeating: 0, count: fftN)
        vDSP_vmul(data, 1, fftWindow, 1, &windowed, 1, vDSP_Length(fftN))
        
        // Split complex arrays
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        
        // Pack into split complex and run FFT
        real.withUnsafeMutableBufferPointer { rBuf in
            imag.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                windowed.withUnsafeBufferPointer { wBuf in
                    wBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { ptr in
                        vDSP_ctoz(ptr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        
        // Magnitudes
        var mags = [Float](repeating: 0, count: halfN)
        real.withUnsafeMutableBufferPointer { rBuf in
            imag.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(halfN))
            }
        }
        
        // Search 80–2000 Hz
        let minBin = Int(80.0 * Double(fftN) / sampleRate)
        let maxBin = min(Int(2000.0 * Double(fftN) / sampleRate), halfN - 1)
        guard minBin < maxBin else { return nil }
        
        // Find peak
        var peakVal: Float = 0
        var peakIdx: vDSP_Length = 0
        vDSP_maxvi(Array(mags[minBin...maxBin]), 1, &peakVal, &peakIdx, vDSP_Length(maxBin - minBin + 1))
        
        let idx = Int(peakIdx) + minBin
        guard peakVal > 10 else { return nil }
        
        // Parabolic interpolation
        if idx > 0 && idx < halfN - 1 {
            let a = mags[idx - 1]
            let b = mags[idx]
            let c = mags[idx + 1]
            let d = a - 2 * b + c
            let p: Float = d != 0 ? 0.5 * (a - c) / d : 0
            return (Double(idx) + Double(p)) * sampleRate / Double(fftN)
        }
        return Double(idx) * sampleRate / Double(fftN)
    }
    
    // MARK: - Helpers
    
    private func frequencyToSemitone(_ frequency: Double) -> Int {
        let semitonesFromA4 = 12.0 * log2(frequency / 440.0)
        let noteNumber = Int(round(semitonesFromA4)) + 9
        return ((noteNumber % 12) + 12) % 12
    }
    
    private func addDetection(semitone: Int) {
        let now = Date()
        recentDetections.append((semitone: semitone, timestamp: now))
        recentDetections.removeAll { now.timeIntervalSince($0.timestamp) > windowDuration }
        
        semitoneHistogram.removeAll()
        for d in recentDetections {
            semitoneHistogram[d.semitone, default: 0] += 1
        }
        detectedSemitones = Set(semitoneHistogram.keys)
    }
    
    private func updateScaleIdentification() {
        guard detectedSemitones.count >= minDistinctNotes else {
            detectedScale = nil
            confidence = 0
            return
        }
        
        let total = recentDetections.count
        guard total > 0 else { return }
        
        var bestScale: EthiopianScale?
        var bestRoot = 0
        var bestScore: Double = 0
        
        for scale in EthiopianScale.allCases {
            let intervals = Set(scale.intervals)
            for root in 0..<12 {
                let scaleNotes = Set(intervals.map { ($0 + root) % 12 })
                var onScale = 0
                for d in recentDetections {
                    if scaleNotes.contains(d.semitone) { onScale += 1 }
                }
                let score = Double(onScale) / Double(total)
                let distinct = detectedSemitones.intersection(scaleNotes).count
                let bonus = Double(distinct) / Double(scaleNotes.count) * 0.2
                let finalScore = score + bonus
                if finalScore > bestScore {
                    bestScore = finalScore
                    bestScale = scale
                    bestRoot = root
                }
            }
        }
        
        let norm = min(bestScore / 1.2, 1.0)
        if norm > 0.4, let scale = bestScale {
            detectedScale = scale
            confidence = norm
            detectedRootName = ScaleNote.chromaticNames[bestRoot]
        } else {
            detectedScale = nil
            confidence = norm
        }
    }
}
