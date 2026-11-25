import Foundation
import CoreGraphics
import AppKit

// Sends bounded native key holds to a verified debugger PID.
let arguments = CommandLine.arguments
guard arguments.count == 4, let pid = Int32(arguments[1]),
      let duration = Double(arguments[3]), duration > 0, duration <= 30 else {
    fatalError("usage: racing_key_hold PID comma-separated-keycodes seconds")
}
let keys = arguments[2].split(separator: ",").compactMap { UInt16($0) }
guard let app = NSRunningApplication(processIdentifier: pid),
      app.bundleIdentifier?.hasPrefix("local.racingclone.debugger.client") == true else {
    fatalError("target must be a running Racing debugger client")
}
app.activate(options: [.activateIgnoringOtherApps])
let source = CGEventSource(stateID: .hidSystemState)
for key in keys {
    CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)?.post(tap: .cghidEventTap)
}
Thread.sleep(forTimeInterval: duration)
for key in keys.reversed() {
    CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)?.post(tap: .cghidEventTap)
}
