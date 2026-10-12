//
//  AboutView.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else if let fallbackIcon = NSImage(named: "AppIcon") {
                Image(nsImage: fallbackIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "bolt.batteryblock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .frame(width: 80, height: 80)
            }

            VStack(spacing: 4) {
                Text("BatteryGuard")
                    .font(.system(size: 20, weight: .bold))
                Text("Version \(appVersion)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text("A lightweight, zero-bloat charge limiter and sailing monitor for Apple Silicon.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)

            Divider()

            VStack(spacing: 2) {
                Text("Developed by Aneeth Kumaar")
                    .font(.system(size: 11, weight: .medium))
                Text("Open-source")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 280)
    }
}
