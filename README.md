# DrumBridge

Drum MIDI map translator for Logic Pro (macOS AUv3 MIDI FX).
Each controller and each drum plugin is described once against one standard set of drum sounds,
so any pads play any kit without remapping.

```
controller ──► [device profile] ──► DrumBridge standard ──► [plugin profile] ──► Kontakt / Drum Kit Designer / Tekno…
```

## Use in Logic
On the drum track: **MIDI FX slot › Audio Units › DrumBridge › Drum Map Translator**.
Pick your controller and plugin at the top. Tabs: Map (with Learn), Plugin (notes + ▶ audition), Settings, Monitor.
Settings are saved in the Logic project; *Save as default* sets what new instances start with.

Built-in devices: Arturia KeyLab Essential 49 mkII (pads ch 10, Bank A 36–43 / Bank B 44–51, keys = GM),
General MIDI, Roland V-Drums, Alesis, Empty. Plugins: General MIDI (verified); Bogren, Tekno, Blip Box (unverified, start from GM).

## Build
`tools/build.command` (double-click): XcodeGen → xcodebuild Release → installs to /Applications → registers the AU → auval.
`tools/auval.command` re-runs validation. Kernel tests: `cc -std=c11 -IShared/Kernel Shared/Kernel/DBKernel.c Tests/kernel_test.c -lm -o kt && ./kt`

## Code map
Shared/Kernel (C, real-time translation) · Shared/Model (articulations, profiles, presets, compiler) ·
Shared/Engine (state, editing, audition, monitor) · Shared/UI (SwiftUI editor) · AUExtension (AUAudioUnit + view controller) ·
App (container app) · project.yml (XcodeGen)
