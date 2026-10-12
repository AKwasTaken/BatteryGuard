//
//  BatteryIcon.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//

import AppKit

enum BatteryIcon {
    static func make(percent: Int, bolt: Bool) -> NSImage {

        let targetSize = NSSize(width: 22, height: 12)
        let index = min(4, max(0, (percent + 12) / 25))

        let img: NSImage
        if bolt {
            let boltNames = [
                "Battery0Bolt",
                "Battery25Bolt",
                "Battery50Bolt",
                "Battery75Bolt",
                "Battery100Bolt"
            ]
            let name = boltNames[index]
            if let custom = NSImage(named: name) {
                img = custom
            } else if let fallback = NSImage(systemSymbolName: "battery.100percent.bolt", accessibilityDescription: nil) {
                img = fallback
            } else {
                img = NSImage()
            }
        } else {
            let normalNames = [
                "Battery0",
                "Battery25",
                "Battery50",
                "Battery75",
                "Battery100"
            ]
            let name = normalNames[index]
            if let custom = NSImage(named: name) {
                img = custom
            } else {
                let sysNames = [
                    "battery.0percent",
                    "battery.25percent",
                    "battery.50percent",
                    "battery.75percent",
                    "battery.100percent"
                ]
                let cfg = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
                img = NSImage(systemSymbolName: sysNames[index], accessibilityDescription: "Battery")?.withSymbolConfiguration(cfg) ?? NSImage()
            }
        }

        img.size = targetSize
        img.isTemplate = true
        return img
    }
}
