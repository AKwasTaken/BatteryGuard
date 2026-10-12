//
//  SMCBattery.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//

import os

enum SMCBattery {
    private static let log = Logger(subsystem: "ak.BatteryGuard", category: "smc")

    /// true = stop charging. Old macOS: charge-inhibit keys. macOS 27: cut the adapter (CHIE) instead.
    @discardableResult
    static func setInhibit(_ on: Bool) -> Bool {
        guard smc_open() == 0 else { return false }
        var ok = false
        var v: [UInt8] = [on ? 0x02 : 0x00]
        for key in ["CH0B", "CH0C"] where smc_write(key, &v, 1) == 0 { ok = true }
        var t: [UInt8] = on ? [1, 0, 0, 0] : [0, 0, 0, 0]
        if smc_write("CHTE", &t, 4) == 0 { ok = true }

        if !ok {
            var a: [UInt8] = [on ? 0x08 : 0x00]        // 0x08 = adapter off, 0x00 = adapter on
            let r = smc_write("CHIE", &a, 1)
            log.notice("CHIE=\(a[0]) -> \(r)")
            ok = (r == 0)
        }
        return ok
    }

    enum LED: UInt8 { case system = 0x00, green = 0x03, orange = 0x04 }

    static func setLED(_ c: LED) {
        guard smc_open() == 0 else { return }
        var v: [UInt8] = [c.rawValue]
        _ = smc_write("ACLC", &v, 1)
    }
}
