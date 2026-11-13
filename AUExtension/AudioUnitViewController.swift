import CoreAudioKit
import SwiftUI

/// Principal class of the extension: creates the AU and hosts the SwiftUI editor.
public final class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    private var audioUnit: DrumBridgeAudioUnit?
    private var hostingView: NSView?

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 560))
        preferredContentSize = NSSize(width: 760, height: 560)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        attachEditorIfReady()
    }

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let au = try DrumBridgeAudioUnit(componentDescription: componentDescription, options: [])
        audioUnit = au
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isViewLoaded else { return }
            self.attachEditorIfReady()
        }
        return au
    }

    private func attachEditorIfReady() {
        guard let au = audioUnit, hostingView == nil else { return }
        let h = NSHostingView(rootView: DrumBridgeView(engine: au.engine))
        h.frame = view.bounds
        h.autoresizingMask = [.width, .height]
        view.addSubview(h)
        hostingView = h
    }
}
