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
    private let bufferSize: AVAudioFrameCount = 8192
    private var sampleRate: Double = 44100
    
    // Weighted detection history: each detection carries its signal strength
    private struct NoteDetection {
        let semitone: Int
        let weight: Double     // signal strength weight
        let timestamp: Date
    }
    private var recentDetections: [NoteDetection] = []
    private let windowDuration: TimeInterval = 6.0  // longer window for better accumulation
    private let minDistinctNotes = 3
    
    // Smoothing: track last N scale results for temporal stability
    private var scaleHistory: [(scale: EthiopianScale, root: Int, score: Double)] = []
    private let historySize = 8
    
    // FFT resources — 8192-point for ~5Hz resolution at 44.1kHz
    private let fftN = 8192
    private let log2n: vDSP_Length = 13
    private var fftSetup: FFTSetup?
    private var fftWindow = [Float](repeating: 0, count: 8192)
    
    // Accumulation buffer for overlapping analysis
    private var accumulationBuffer = [Float]()
    private let overlapSize = 8192
    
    init() {
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        vDSP_hann_window(&fftWindow, vDSP_Length(fftN), Int32(vDSP_HANN_NORM))
    }
    
    // MARK: - Lifecycle
    
    func startListening() {
        guard !isListening else { return }
        reset()
        
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("AudioAnalyzer: Failed to configure audio session: \(error)")
        }
        #endif
        
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
        
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("AudioAnalyzer: Failed to restore audio session: \(error)")
        }
        #endif
    }
    
    func reset() {
        detectedScale = nil
        confidence = 0
        detectedRootName = ""
        detectedSemitones = []
        dominantFrequency = 0
        inputLevel = 0
        recentDetections.removeAll()
        scaleHistory.removeAll()
        accumulationBuffer.removeAll()
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
        
        // Accumulate samples for overlap
        let newSamples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        accumulationBuffer.append(contentsOf: newSamples)
        
        // Only analyze when we have enough samples
        guard accumulationBuffer.count >= fftN else {
            DispatchQueue.main.async { self.inputLevel = level }
            return
        }
        
        guard level > 0.008 else {
            // Keep half for overlap
            if accumulationBuffer.count > fftN {
                accumulationBuffer.removeFirst(accumulationBuffer.count - fftN / 2)
            }
            DispatchQueue.main.async { self.inputLevel = level }
            return
        }
        
        // Analyze using the most recent fftN samples
        let analysisStart = accumulationBuffer.count - fftN
        let analysisData = Array(accumulationBuffer[analysisStart...])
        
        // Keep half for overlap
        accumulationBuffer.removeFirst(accumulationBuffer.count - fftN / 2)
        
        // Detect multiple prominent pitches
        let detectedPitches = detectPitches(analysisData, signalLevel: Double(level))
        
        guard !detectedPitches.isEmpty else {
            DispatchQueue.main.async { self.inputLevel = level }
            return
        }
        
        DispatchQueue.main.async {
            self.inputLevel = level
            self.dominantFrequency = detectedPitches.first?.frequency ?? 0
            
            for pitch in detectedPitches {
                self.addDetection(
                    semitone: pitch.semitone,
                    weight: pitch.strength
                )
            }
            self.updateScaleIdentification()
        }
    }
    
    // MARK: - Pitch Detection (Harmonic Product Spectrum)
    
    private struct DetectedPitch {
        let frequency: Double
        let semitone: Int
        let strength: Double
    }
    
    private func detectPitches(_ data: [Float], signalLevel: Double) -> [DetectedPitch] {
        guard data.count >= fftN, let setup = fftSetup else { return [] }
        
        let halfN = fftN / 2
        
        // Window the input
        var windowed = [Float](repeating: 0, count: fftN)
        data.withUnsafeBufferPointer { dataBuf in
            fftWindow.withUnsafeBufferPointer { winBuf in
                vDSP_vmul(dataBuf.baseAddress!, 1, winBuf.baseAddress!, 1, &windowed, 1, vDSP_Length(fftN))
            }
        }
        
        // Split complex arrays
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        
        // Pack and FFT
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
        
        // Convert to dB scale for better dynamic range
        var dbMags = [Float](repeating: 0, count: halfN)
        var one: Float = 1.0
        vDSP_vdbcon(mags, 1, &one, &dbMags, 1, vDSP_Length(halfN), 0)
        
        // Harmonic Product Spectrum: multiply spectrum at harmonic intervals
        // This helps find the fundamental even when harmonics are stronger
        let hpsHarmonics = 3
        var hps = [Float](repeating: 0, count: halfN)
        for i in 0..<halfN { hps[i] = mags[i] }
        
        for h in 2...hpsHarmonics {
            for i in 0..<(halfN / h) {
                hps[i] *= mags[i * h]
            }
        }
        
        // Search range: 65 Hz (C2) to 2000 Hz
        let minBin = max(1, Int(65.0 * Double(fftN) / sampleRate))
        let maxBin = min(Int(2000.0 * Double(fftN) / sampleRate), halfN / hpsHarmonics - 1)
        guard minBin < maxBin else { return [] }
        
        // Find multiple peaks in HPS
        var peaks: [(bin: Int, value: Float)] = []
        let noiseFloor = findNoiseFloor(mags, minBin: minBin, maxBin: maxBin)
        let threshold = noiseFloor * 8.0  // peaks must be well above noise
        
        for i in (minBin + 1)..<maxBin {
            if hps[i] > hps[i - 1] && hps[i] > hps[i + 1] && hps[i] > threshold {
                peaks.append((bin: i, value: hps[i]))
            }
        }
        
        // Sort by strength, keep top peaks
        peaks.sort { $0.value > $1.value }
        let topPeaks = peaks.prefix(4)
        
        guard let strongestPeak = topPeaks.first else { return [] }
        
        var results: [DetectedPitch] = []
        
        for peak in topPeaks {
            // Only include peaks that are at least 15% as strong as the strongest
            guard Double(peak.value) > Double(strongestPeak.value) * 0.15 else { continue }
            
            // Parabolic interpolation on the original magnitude spectrum
            // for more precise frequency
            let idx = peak.bin
            var freq: Double
            if idx > 0 && idx < halfN - 1 {
                let a = mags[idx - 1]
                let b = mags[idx]
                let c = mags[idx + 1]
                let denom = a - 2 * b + c
                let p: Float = denom != 0 ? 0.5 * (a - c) / denom : 0
                freq = (Double(idx) + Double(p)) * sampleRate / Double(fftN)
            } else {
                freq = Double(idx) * sampleRate / Double(fftN)
            }
            
            guard freq > 0, freq.isFinite else { continue }
            
            let semitone = frequencyToSemitone(freq)
            let strengthRaw = Double(peak.value) / Double(strongestPeak.value) * signalLevel
            let strength = strengthRaw.isFinite ? strengthRaw : 0
            
            results.append(DetectedPitch(
                frequency: freq,
                semitone: semitone,
                strength: strength
            ))
        }
        
        return results
    }
    
    /// Estimate noise floor as median of magnitude values in range
    private func findNoiseFloor(_ mags: [Float], minBin: Int, maxBin: Int) -> Float {
        guard minBin <= maxBin else { return 1.0 }
        let slice = Array(mags[minBin...maxBin]).filter { $0.isFinite }.sorted()
        guard !slice.isEmpty else { return 1.0 }
        return max(slice[slice.count / 2], Float.leastNormalMagnitude)
    }
    
    // MARK: - Helpers
    
    private func frequencyToSemitone(_ frequency: Double) -> Int {
        guard frequency > 0, frequency.isFinite else { return 0 }
        let semitonesFromA4 = 12.0 * log2(frequency / 440.0)
        guard semitonesFromA4.isFinite else { return 0 }
        let noteNumber = Int(round(semitonesFromA4)) + 9
        return ((noteNumber % 12) + 12) % 12
    }
    
    private func addDetection(semitone: Int, weight: Double) {
        let now = Date()
        recentDetections.append(NoteDetection(
            semitone: semitone,
            weight: weight,
            timestamp: now
        ))
        // Prune old detections
        recentDetections.removeAll { now.timeIntervalSince($0.timestamp) > windowDuration }
        
        // Build weighted semitone set
        var weightedCounts = [Int: Double]()
        for d in recentDetections {
            // Time decay: more recent detections count more
            let age = now.timeIntervalSince(d.timestamp)
            let decay = max(0.1, 1.0 - age / windowDuration)
            weightedCounts[d.semitone, default: 0] += d.weight * decay
        }
        
        // Only include semitones with meaningful weight
        let maxWeight = weightedCounts.values.max() ?? 1.0
        let threshold = maxWeight * 0.08
        detectedSemitones = Set(weightedCounts.filter { $0.value > threshold }.keys)
    }
    
    private func updateScaleIdentification() {
        guard detectedSemitones.count >= minDistinctNotes else {
            detectedScale = nil
            confidence = 0
            return
        }
        
        let now = Date()
        
        // Build weighted histogram with time decay
        var weightedHist = [Int: Double]()
        var totalWeight: Double = 0
        for d in recentDetections {
            let age = now.timeIntervalSince(d.timestamp)
            let decay = max(0.1, 1.0 - age / windowDuration)
            let w = d.weight * decay
            weightedHist[d.semitone, default: 0] += w
            totalWeight += w
        }
        
        guard totalWeight > 0 else { return }
        
        var bestScale: EthiopianScale?
        var bestRoot = 0
        var bestScore: Double = 0
        
        for scale in EthiopianScale.allCases {
            let intervals = Set(scale.intervals)
            for root in 0..<12 {
                let scaleNotes = Set(intervals.map { ($0 + root) % 12 })
                
                // Weighted on-scale ratio
                var onScaleWeight: Double = 0
                for (semitone, weight) in weightedHist {
                    if scaleNotes.contains(semitone) {
                        onScaleWeight += weight
                    }
                }
                let matchRatio = onScaleWeight / totalWeight
                
                // Coverage bonus: how many of the 5 scale notes are present
                let distinctMatched = detectedSemitones.intersection(scaleNotes).count
                let coverageBonus = Double(distinctMatched) / Double(scaleNotes.count) * 0.25
                
                // Penalty for off-scale notes that are strongly detected
                var offScaleWeight: Double = 0
                for (semitone, weight) in weightedHist {
                    if !scaleNotes.contains(semitone) {
                        offScaleWeight += weight
                    }
                }
                let offScalePenalty = (offScaleWeight / totalWeight) * 0.15
                
                let finalScore = matchRatio + coverageBonus - offScalePenalty
                
                if finalScore > bestScore {
                    bestScore = finalScore
                    bestScale = scale
                    bestRoot = root
                }
            }
        }
        
        // Temporal smoothing: add to history and vote
        if let scale = bestScale {
            scaleHistory.append((scale: scale, root: bestRoot, score: bestScore))
            if scaleHistory.count > historySize {
                scaleHistory.removeFirst()
            }
        }
        
        // Vote across recent history for stability
        let (smoothedScale, smoothedRoot, smoothedConfidence) = smoothedResult()
        
        if smoothedConfidence > 0.35, let scale = smoothedScale {
            detectedScale = scale
            confidence = smoothedConfidence
            detectedRootName = ScaleNote.chromaticNames[smoothedRoot]
        } else {
            detectedScale = nil
            confidence = smoothedConfidence
        }
    }
    
    /// Vote across recent scale history for temporal stability
    private func smoothedResult() -> (EthiopianScale?, Int, Double) {
        guard !scaleHistory.isEmpty else { return (nil, 0, 0) }
        
        // Weight more recent results higher
        var votes = [String: (scale: EthiopianScale, root: Int, totalScore: Double, count: Double)]()
        
        for (i, entry) in scaleHistory.enumerated() {
            let recencyWeight = Double(i + 1) / Double(scaleHistory.count)  // newer = higher
            let key = "\(entry.scale.rawValue)_\(entry.root)"
            
            if var existing = votes[key] {
                existing.totalScore += entry.score * recencyWeight
                existing.count += recencyWeight
                votes[key] = existing
            } else {
                votes[key] = (scale: entry.scale, root: entry.root,
                             totalScore: entry.score * recencyWeight, count: recencyWeight)
            }
        }
        
        // Find the winner
        guard let winner = votes.values.max(by: { $0.totalScore < $1.totalScore }) else {
            return (nil, 0, 0)
        }
        
        let avgScore = winner.totalScore / winner.count
        let norm = min(avgScore / 1.1, 1.0)
        return (winner.scale, winner.root, norm)
    }
}
