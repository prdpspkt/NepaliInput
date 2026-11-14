import Cocoa
import InputMethodKit

// MARK: - Nepali Input Entry Point

/// Global reference to the IMKCandidates window.
/// Used by NepaliInputController to show/hide/update the system candidate panel.
/// This is the same native candidate window used by macOS built-in transliteration.
var candidatesWindow: IMKCandidates!

let bundleIdentifier = Bundle.main.bundleIdentifier!
let connectionName = Bundle.main.infoDictionary!["InputMethodConnectionName"] as! String

// Initialize IMKServer — registers our controller class with the system
let server = IMKServer(name: connectionName, bundleIdentifier: bundleIdentifier)

// Initialize the system candidate window — same style as built-in Hindi Transliteration
candidatesWindow = IMKCandidates(server: server, panelType: kIMKSingleColumnScrollingCandidatePanel)

NSLog("NepaliInput: Server started — connection: \(connectionName)")

NSApplication.shared.run()
