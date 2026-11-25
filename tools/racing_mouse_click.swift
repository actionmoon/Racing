import Foundation
import AppKit
import CoreGraphics

// Target a verified debugger window using fractions of its current screenshot.
let args = CommandLine.arguments
guard (5...6).contains(args.count), let pid = Int32(args[1]), let id = UInt32(args[2]),
      let fx = Double(args[3]), let fy = Double(args[4]),
      fx > 0, fx < 1, fy > 0, fy < 1,
      let app = NSRunningApplication(processIdentifier: pid),
      app.bundleIdentifier?.hasPrefix("local.racingclone.debugger.client") == true
else { fatalError("Expected client PID, window ID and two fractions") }
let holdSeconds = args.count == 6 ? Double(args[5]) ?? 0 : 0.2
guard holdSeconds > 0, holdSeconds <= 30 else { fatalError("Hold duration must be between 0 and 30 seconds") }
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
guard let window = windows.first(where: {
    ($0[kCGWindowNumber as String] as? UInt32) == id &&
    ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid)
}), let raw = window[kCGWindowBounds as String] as? [String: Any],
      let frame = CGRect(dictionaryRepresentation: raw as CFDictionary)
else { fatalError("Client window is no longer visible") }
let point = CGPoint(x: frame.minX + frame.width * fx, y: frame.minY + frame.height * fy)
app.activate(options: [])
CGWarpMouseCursorPosition(point)
let source = CGEventSource(stateID: .hidSystemState)
for kind in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
    let event = CGEvent(mouseEventSource: source, mouseType: kind, mouseCursorPosition: point, mouseButton: .left)!
    CGWarpMouseCursorPosition(point)
    event.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: kind == .leftMouseDown ? holdSeconds : 0.2)
}
print("Sent mouse events to verified client; requested \(point), actual \(CGEvent(source: nil)!.location)")
