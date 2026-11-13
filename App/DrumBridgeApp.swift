import SwiftUI

/// The container app. Launching it once registers the DrumBridge Audio Unit with macOS.
@main
struct DrumBridgeApp: App {
    var body: some Scene {
        WindowGroup("DrumBridge") {
            InstallView()
                .frame(minWidth: 480, minHeight: 340)
        }
        .windowResizability(.contentSize)
    }
}

struct InstallView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DrumBridge").font(.largeTitle.bold())
            Text("Drum map translator for Logic Pro").foregroundStyle(.secondary)
            Divider()
            Label("The plug-in is installed. You can close this window.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 6) {
                Text("In Logic:").bold()
                Text("1. Select your drum track (Kontakt, Drum Kit Designer, Tekno…).")
                Text("2. Click the MIDI FX slot › Audio Units › DrumBridge › Drum Map Translator.")
                Text("3. Pick your controller and your drum plugin at the top. Play the pads.")
                Text("If it isn't listed, quit and reopen Logic (Logic rescans plug-ins on launch).")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
    }
}
