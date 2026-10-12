//
//  BatteryXPC.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//

import Foundation
import IOKit.ps

struct PowerSnapshot {
    var percent: Int, onAC: Bool, charging: Bool

    static func read() -> PowerSnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let src = list.first,
              let d = IOPSGetPowerSourceDescription(info, src)?.takeUnretainedValue() as? [String: Any]
        else { return nil }
        return .init(percent: d[kIOPSCurrentCapacityKey] as? Int ?? 0,
                     onAC: (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
                     charging: d[kIOPSIsChargingKey] as? Bool ?? false)
    }
}

final class PowerWatcher {
    private let fn: () -> Void
    private var src: CFRunLoopSource?
    init(_ fn: @escaping () -> Void) {
        self.fn = fn
        let me = Unmanaged.passUnretained(self).toOpaque()
        src = IOPSNotificationCreateRunLoopSource({ p in
            Unmanaged<PowerWatcher>.fromOpaque(p!).takeUnretainedValue().fn()
        }, me)?.takeRetainedValue()
        if let s = src { CFRunLoopAddSource(CFRunLoopGetMain(), s, .commonModes) }
    }
    deinit { if let s = src { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) } }
}
