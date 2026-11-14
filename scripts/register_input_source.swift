// Registers and enables the Nepali Input input method with Text Input Services.
// Compiled and run by scripts/install.sh. Usage: register_input_source <path-to-.app> <input-source-id>

import Foundation
import Carbon

// Usage:
//   register_input_source <app-path> <input-source-id>            register and enable
//   register_input_source --disable <app-path> <input-source-id>  disable

let args = Array(CommandLine.arguments.dropFirst())
let disable = args.first == "--disable"
let rest = disable ? Array(args.dropFirst()) : args

guard rest.count == 2 else {
    fputs("usage: register_input_source [--disable] <app-path> <input-source-id>\n", stderr)
    exit(2)
}

let appURL = URL(fileURLWithPath: rest[0]) as CFURL
let sourceID = rest[1]

// Find the input source by its ID.
func findSource() -> TISInputSource? {
    let filter = [kTISPropertyInputSourceID as String: sourceID] as CFDictionary
    let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource]
    return list?.first
}

if disable {
    guard let source = findSource() else {
        print("Input source \(sourceID) not registered; nothing to disable.")
        exit(0)
    }
    let status = TISDisableInputSource(source)
    if status != noErr {
        fputs("TISDisableInputSource failed: \(status)\n", stderr)
        exit(1)
    }
    print("Disabled \(sourceID)")
    exit(0)
}

// 1. Register the input method bundle (equivalent to macOS discovering it at login).
let regStatus = TISRegisterInputSource(appURL)
if regStatus != noErr && regStatus != OSStatus(-50) { // -50 = already registered
    fputs("TISRegisterInputSource failed: \(regStatus)\n", stderr)
    exit(1)
}

// 2. Locate the source; it may need a login before macOS lists it.
guard let source = findSource() else {
    fputs("Input source \(sourceID) not found after registration. Log out and back in, then rerun.\n", stderr)
    exit(1)
}

// 3. Enable it so it appears in System Settings → Input Sources.
let enableStatus = TISEnableInputSource(source)
if enableStatus != noErr {
    fputs("TISEnableInputSource failed: \(enableStatus)\n", stderr)
    exit(1)
}

print("Registered and enabled \(sourceID)")
