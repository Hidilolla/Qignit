import AVFoundation
import Observation

/// Generates sine wave tones using AVAudioEngine for playing pentatonic scale notes.
@Observable
final class ToneGenerator {
    
    private let audioEngine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    
    private var currentFrequency: Double = 0
    private var targetFrequency: Double = 0
    private var amplitude: Double = 0
    private var targetAmplitude: Double = 0
    private var phase: Double = 0
    private var sampleRate: Double = 44100
    
    /// Whether a note is currently sounding.
    private(set) var isPlaying = false
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
        #endif
    }
    
    private func setupAudioEngine() {
        let outputFormat = audioEngine.outputNode.outputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate
        
        let inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        
        // Capture properties for the render block (real-time safe)
        var localPhase = 0.0
        var localAmplitude = 0.0
        var localFrequency = 0.0
        let localSampleRate = sampleRate
        
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            
            let targetFreq = self.targetFrequency
            let targetAmp = self.targetAmplitude
            
            let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let buffer = bufferList[0]
            let ptr = buffer.mData?.assumingMemoryBound(to: Float.self)
            
            let rampSpeed = 0.005
            
            for frame in 0..<Int(frameCount) {
                // Smooth frequency and amplitude transitions
                localFrequency += (targetFreq - localFrequency) * rampSpeed
                localAmplitude += (targetAmp - localAmplitude) * rampSpeed
                
                let phaseIncrement = 2.0 * Double.pi * localFrequency / localSampleRate
                localPhase += phaseIncrement
                if localPhase > 2.0 * Double.pi {
                    localPhase -= 2.0 * Double.pi
                }
                
                // Sine wave with slight harmonic richness
                let sine = sin(localPhase)
                let harmonic = sin(localPhase * 2.0) * 0.15
                let sample = Float(localAmplitude * (sine + harmonic))
                
                ptr?[frame] = sample
            }
            
            return noErr
        }
        
        sourceNode = node
        audioEngine.attach(node)
        
        let mainMixer = audioEngine.mainMixerNode
        audioEngine.connect(node, to: mainMixer, format: inputFormat)
        mainMixer.outputVolume = 0.5
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// Play a note at the given frequency.
    func playNote(frequency: Double) {
        targetFrequency = frequency
        targetAmplitude = 0.4
        isPlaying = true
    }
    
    /// Stop the currently playing note.
    func stopNote() {
        targetAmplitude = 0
        isPlaying = false
    }
    
    deinit {
        audioEngine.stop()
    }
}
