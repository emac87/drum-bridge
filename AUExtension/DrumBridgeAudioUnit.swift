import AudioToolbox
import AVFoundation
import CoreAudioKit

/// AUv3 MIDI processor ('aumi'): translates drum notes on the way to the instrument.
public final class DrumBridgeAudioUnit: AUAudioUnit {
    let engine: DrumBridgeEngine

    private var outputBus: AUAudioUnitBus!
    private var _outputBusses: AUAudioUnitBusArray!
    private var _inputBusses: AUAudioUnitBusArray!

    // Render-thread resources, set up in allocateRenderResources.
    private var midiOut: AUMIDIOutputEventBlock?
    private let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 3 * 256)
    private var silence: UnsafeMutablePointer<Float>?
    private var silenceFrames: AUAudioFrameCount = 0
    private static let stateKey = "drumbridge"

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        engine = DrumBridgeEngine()
        try super.init(componentDescription: componentDescription, options: options)

        // Hosts (Logic included) drive MIDI FX through an audio render call, so expose one silent output bus.
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = 2
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
        parameterTree = AUParameterTree.createTree(withChildren: [])
        maximumFramesToRender = 4096
    }

    deinit {
        scratch.deallocate()
        silence?.deallocate()
    }

    public override var outputBusses: AUAudioUnitBusArray { _outputBusses }
    public override var inputBusses: AUAudioUnitBusArray { _inputBusses }

    public override var midiOutputNames: [String] { ["DrumBridge Out"] }
    public override var supportsUserPresets: Bool { false }
    public override var canProcessInPlace: Bool { true }

    // MARK: State saved in the Logic project

    public override var fullState: [String: Any]? {
        get {
            var s = super.fullState ?? [:]
            if let d = engine.stateData() { s[Self.stateKey] = d }
            return s
        }
        set {
            super.fullState = newValue
            guard let d = newValue?[Self.stateKey] as? Data else { return }
            if Thread.isMainThread { engine.load(stateData: d) }
            else { DispatchQueue.main.async { [engine] in engine.load(stateData: d) } }
        }
    }

    // MARK: Render

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        midiOut = midiOutputEventBlock
        let frames = maximumFramesToRender
        if silence == nil || silenceFrames < frames {
            silence?.deallocate()
            silence = .allocate(capacity: Int(frames) * 2)
            silence!.initialize(repeating: 0, count: Int(frames) * 2)
            silenceFrames = frames
        }
    }

    public override func deallocateRenderResources() {
        midiOut = nil
        super.deallocateRenderResources()
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let kernel = engine.kernel
        let scratch = self.scratch
        return { [unowned self] _, _, frameCount, _, outputData, eventList, _ in
            // Silent audio out.
            let abl = UnsafeMutableAudioBufferListPointer(outputData)
            for i in 0..<abl.count {
                let bytes = Int(frameCount) * MemoryLayout<Float>.size
                if let p = abl[i].mData {
                    memset(p, 0, bytes)
                } else if let s = self.silence {
                    abl[i].mData = UnsafeMutableRawPointer(s + i % 2 * Int(self.silenceFrames))
                }
                abl[i].mDataByteSize = UInt32(bytes)
            }

            guard let out = self.midiOut else {
                // No MIDI output connected: still keep the kernel's table handshake moving.
                while db_kernel_pop_audition(kernel, scratch) == 3 {}
                return noErr
            }

            var ev = eventList
            while let e = ev {
                if e.pointee.head.eventType == .MIDI {
                    var midi = e.pointee.MIDI
                    let len = Int32(min(Int(midi.length), 3))
                    let n = withUnsafeBytes(of: &midi.data) { raw -> Int32 in
                        db_kernel_process(kernel, raw.bindMemory(to: UInt8.self).baseAddress, len, scratch)
                    }
                    if n > 0 { _ = out(midi.eventSampleTime, midi.cable, Int(n), scratch) }
                }
                ev = UnsafePointer(e.pointee.head.next)
            }

            while db_kernel_pop_audition(kernel, scratch) == 3 {
                _ = out(AUEventSampleTimeImmediate, 0, 3, scratch)
            }
            return noErr
        }
    }
}
