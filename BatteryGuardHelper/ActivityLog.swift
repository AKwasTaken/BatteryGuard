//
//  ActivityLog.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 27/10/26.
//


import Foundation
import IOKit

/// One file per day: /Library/Logs/BatteryGuard/YYYY-MM-DD.log
enum ActivityLog {
    static let dir = URL(fileURLWithPath: "/Library/Logs/BatteryGuard", isDirectory: true)
    private static let queue = DispatchQueue(label: "ak.BatteryGuard.activitylog")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }
    private static let dayFormat = formatter("yyyy-MM-dd")
    private static let timeFormat = formatter("yyyy-MM-dd HH:mm:ss.SSS")

    /// Appends one line. Writes happen off the main thread, in order.
    static func write(_ tag: String, _ message: String) {
        let now = Date()
        queue.async {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("\(dayFormat.string(from: now)).log")
            let line = "\(timeFormat.string(from: now)) [\(tag)] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: file) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: file)
            }
        }
    }

    /// Call before exit() so the last lines are on disk.
    static func flush() { queue.sync {} }

    /// Battery and adapter state as the OS reports it.
    static func batterySnapshot() -> String {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard svc != 0 else { return "battery=unavailable" }
        defer { IOObjectRelease(svc) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(svc, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return "battery=unreadable"
        }

        // Signed values can come back as huge unsigned numbers, so convert by bit pattern.
        func int(_ k: String) -> Int64? {
            guard let n = dict[k] as? NSNumber else { return nil }
            return Int64(bitPattern: n.uint64Value)
        }
        func text(_ k: String) -> String { int(k).map { "\($0)" } ?? "?" }
        func flag(_ k: String) -> String {
            guard let n = dict[k] as? NSNumber else { return "?" }
            return n.boolValue ? "yes" : "no"
        }

        let temp = int("Temperature").map { String(format: "%.1f", Double($0) / 100) } ?? "?"
        let watts = (dict["AdapterDetails"] as? [String: Any])
            .flatMap { ($0["Watts"] as? NSNumber)?.int64Value }
            .map { "\($0)" } ?? "none"

        return "cap=\(text("CurrentCapacity"))/\(text("MaxCapacity")) ext=\(flag("ExternalConnected")) "
             + "charging=\(flag("IsCharging")) full=\(flag("FullyCharged")) "
             + "amps=\(text("InstantAmperage"))mA volts=\(text("Voltage"))mV "
             + "cycles=\(text("CycleCount")) temp=\(temp)C adapterW=\(watts)"
    }
}
