import Foundation
import AVFoundation
import Combine

/// Tiny synth: one voice, sine + a little triangle, short attack and a soft release.
/// Uses `AVAudioEngine` with an `AVAudioSourceNode`; no samples.
/// The audio session is `.ambient`, so the silent switch mutes it and other audio keeps playing.
final class ToneSynth: ObservableObject {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var isConfigured = false

    private let lock = NSLock()
    private var sampleRate: Double = 44_100
    // Voice state, guarded by `lock`.
    private var phase: Double = 0
    private var phaseIncrement: Double = 0
    /// Seconds since note-on; negative means silent.
    private var envelopeTime: Double = -1
    private var noteGeneration: UInt64 = 0

    private let attack = 0.012
    private let duration = 0.75
    private let amplitude = 0.28

    init() {
        configureSession()
        buildGraph()
    }

    deinit {
        engine.stop()
    }

    // MARK: - Public

    func play(note: Note) {
        play(frequency: note.frequency)
    }

    func play(frequency: Double) {
        guard isConfigured else { return }
        if !engine.isRunning {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            } catch {
                print("ToneSynth: could not start engine: \(error)")
                return
            }
        }
        lock.lock()
        phaseIncrement = frequency / sampleRate
        phase = 0
        envelopeTime = 0
        noteGeneration &+= 1
        lock.unlock()
    }

    // MARK: - Setup

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("ToneSynth: audio session error: \(error)")
        }
    }

    private func buildGraph() {
        let output = engine.outputNode
        let outputFormat = output.inputFormat(forBus: 0)
        let rate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100
        sampleRate = rate

        guard let monoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: rate,
                                             channels: 1,
                                             interleaved: false) else {
            return
        }

        let node = AVAudioSourceNode(format: monoFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            if let self = self {
                self.render(frameCount: Int(frameCount), into: buffers)
            } else {
                for buffer in buffers {
                    if let data = buffer.mData {
                        memset(data, 0, Int(buffer.mDataByteSize))
                    }
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: monoFormat)
        engine.connect(engine.mainMixerNode, to: output, format: outputFormat)
        engine.mainMixerNode.outputVolume = 1.0
        engine.prepare()
        sourceNode = node
        isConfigured = true
    }

    // MARK: - Rendering (audio thread)

    private func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        lock.lock()
        var localPhase = phase
        let increment = phaseIncrement
        var t = envelopeTime
        let generation = noteGeneration
        lock.unlock()

        let dt = 1.0 / sampleRate
        let twoPi = 2.0 * Double.pi

        for frame in 0..<frameCount {
            var sample: Float = 0
            if t >= 0 && t < duration {
                let env: Double
                if t < attack {
                    env = t / attack
                } else {
                    let r = (t - attack) / (duration - attack)
                    env = pow(max(0, 1 - r), 2.2)
                }
                let sine = sin(twoPi * localPhase)
                let triangle = 2.0 * abs(2.0 * (localPhase - floor(localPhase + 0.5))) - 1.0
                sample = Float((0.72 * sine + 0.28 * triangle) * env * amplitude)
                localPhase += increment
                if localPhase >= 1 { localPhase -= 1 }
                t += dt
            } else if t >= duration {
                t = -1
            }
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let pointer = data.assumingMemoryBound(to: Float.self)
                if frame < Int(buffer.mDataByteSize) / MemoryLayout<Float>.size {
                    pointer[frame] = sample
                }
            }
        }

        lock.lock()
        // Only write back if no new note started while we were rendering.
        if generation == noteGeneration {
            phase = localPhase
            envelopeTime = t
        }
        lock.unlock()
    }
}
