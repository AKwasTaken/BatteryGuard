//
//  NativeLimit.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import Foundation
import os

/// Drives Apple's own Charge Limit (the one behind System Settings > Battery) on macOS 27.
enum NativeLimit {
    private static let domain = "com.apple.smartcharging.topoffprotection"
    private static let log = Logger(subsystem: "ak.BatteryGuard", category: "native")

    private static func run(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func current() -> Int? {
        run("/usr/bin/defaults", ["read", domain, "mclLimitValue"]).flatMap { Int($0) }
    }

    /// Sets the ceiling. Callers must never pass a value below the current charge,
    /// or the Mac will actively drain itself from wall power.
    @discardableResult
    static func set(_ percent: Int) -> Bool {
        let v = min(max(percent, 20), 100)
        guard run("/usr/bin/defaults", ["write", domain, "mclLimitValue", "-int", String(v)]) != nil else {
            log.error("defaults write failed")
            return false
        }
        _ = run("/usr/bin/notifyutil", ["-p", "com.apple.smartcharging.defaultschanged"])
        let ok = current() == v
        log.notice("ceiling=\(v) applied=\(ok)")
        return ok
    }
}