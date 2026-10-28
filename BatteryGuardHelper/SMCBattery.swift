//
//  SMCBattery.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//



import os
import Foundation

enum SMCBattery {
    private static let log = Logger(subsystem: "ak.BatteryGuard", category: "smc")

    /// Per-key result of the last inhibit write, for the activity log.
    private(set) static var lastPath = "none"

    static func fourccString(_ k: UInt32) -> String {
        let bytes: [UInt8] = [UInt8(k >> 24), UInt8((k >> 16) & 0xff), UInt8((k >> 8) & 0xff), UInt8(k & 0xff)]
        return String(bytes: bytes, encoding: .ascii) ?? "????"
    }

    /// Reports which known charge-inhibit keys exist on this Mac, at helper startup.
    static func probe() {
        guard smc_open() == 0 else {
            ActivityLog.write("SMC", "probe skipped: AppleSMC not reachable")
            return
        }
        var parts: [String] = []
        for key in ["CH0B", "CH0C", "CHTE", "CHIE"] {
            var size: UInt32 = 0
            let r = smc_keyinfo(key, &size)
            parts.append(r == 0 ? "\(key)=size\(size)" : "\(key)=err\(r)")
        }
        ActivityLog.write("SMC", "probe " + parts.joined(separator: " "))
    }

    /// Dumps every SMC key starting with C or B, with its current value.
    /// Used to find which key controls charge inhibit on this Mac.
    static func dumpChargeKeys() {
        guard smc_open() == 0 else {
            ActivityLog.write("SMCKEY", "dump skipped: AppleSMC not reachable")
            return
        }
        var count: UInt32 = 0
        guard smc_key_count(&count) == 0 else {
            ActivityLog.write("SMCKEY", "dump skipped: could not read key count")
            return
        }
        var written = 0
        for i in 0..<count {
            var key: UInt32 = 0
            guard smc_key_at(i, &key) == 0 else { continue }
            let name = fourccString(key)
            guard name.hasPrefix("C") || name.hasPrefix("B") else { continue }
            var buf = [UInt8](repeating: 0, count: 32)
            var size: UInt32 = 0
            guard smc_read_key(key, &buf, &size) == 0 else {
                ActivityLog.write("SMCKEY", "\(name) read failed")
                continue
            }
            let hex = buf.prefix(Int(size)).map { String(format: "%02x", $0) }.joined(separator: " ")
            var attr: UInt8 = 0
            _ = smc_read_key_attr(key, &attr)
            ActivityLog.write("SMCKEY", "\(name) size=\(size) attr=\(String(format: "%02x", attr)) value=\(hex)")
            written += 1
        }
        
        let chieKey: UInt32 = (0x43 << 24) | (0x48 << 16) | (0x49 << 8) | 0x45   // "CHIE"
        var ref: UInt8 = 0
        if smc_read_key_attr(chieKey, &ref) == 0 {
            ActivityLog.write("SMCKEY", "reference CHIE attr=\(String(format: "%02x", ref))")
        }
        
        ActivityLog.write("SMCKEY", "dump done: \(written) C/B keys out of \(count)")
    }

    /// true = stop charging while plugged in, false = allow charging.
    /// Only charge-inhibit keys are written here. The adapter-cut key (CHIE) is never used.
    @discardableResult
    static func setInhibit(_ on: Bool) -> Bool {
        guard smc_open() == 0 else {
            lastPath = "smc unavailable"
            return false
        }
        var results: [String] = []
        var ok = false

        var v: [UInt8] = [on ? 0x02 : 0x00]
        for key in ["CH0B", "CH0C"] {
            let r = smc_write(key, &v, 1)
            results.append("\(key)=\(r)")
            if r == 0 { ok = true }
        }

        var t: [UInt8] = on ? [1, 0, 0, 0] : [0, 0, 0, 0]
        let r = smc_write("CHTE", &t, 4)
        results.append("CHTE=\(r)")
        if r == 0 { ok = true }

        lastPath = results.joined(separator: " ")
        log.notice("inhibit=\(on) \(lastPath, privacy: .public)")
        return ok
    }

    enum LED: UInt8 { case system = 0x00, green = 0x03, orange = 0x04 }

    static func setLED(_ c: LED) {
        guard smc_open() == 0 else { return }
        var v: [UInt8] = [c.rawValue]
        _ = smc_write("ACLC", &v, 1)
    }
}
