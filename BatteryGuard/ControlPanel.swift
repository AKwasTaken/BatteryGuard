//
//  ControlPanel.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import SwiftUI

struct ControlPanel: View {
    @EnvironmentObject var m: BatteryModel
    @ObservedObject var purge = AntPurge.shared
    @AppStorage("upper") var upper = 80.0
    @AppStorage("floor") var floor = 40.0
    @AppStorage("sailing") var sailing = false

    private func push() {
        HelperClient.shared.push(upper: Int(upper), sailing: sailing, floor: Int(floor))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(m.percent)%").font(.system(size: 28, weight: .semibold, design: .rounded))
                Spacer()
                Label(m.onAC ? (m.charging ? "Charging" : "On Power Adapter") : "On Battery",
                      systemImage: m.onAC ? "powerplug.fill" : "battery.50percent")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Toggle(isOn: $sailing) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sailing Mode")
                    Text("Resume charging only at the blue bar")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: sailing) { _ in push() }

            VStack(spacing: 6) {
                RangePill(floor: $floor, limit: $upper, level: Double(m.percent),
                          sailing: sailing, onCommit: push)
                HStack {
                    HStack(spacing: 5) {
                        Capsule().fill(.blue).frame(width: 4, height: 12)
                        Text("Sailing \(Int(floor))%")
                    }.opacity(sailing ? 1 : 0.4)
                    Spacer()
                    HStack(spacing: 5) {
                        Text("Limit \(Int(upper))%")
                        Capsule().fill(.orange).frame(width: 4, height: 12)
                    }
                }
                .font(.caption).monospacedDigit()
            }

            Divider()

            Button {
                purge.remaining > 0 ? purge.stop() : purge.start()
            } label: {
                Label(purge.remaining > 0
                      ? String(format: "Cancel thermal cycle  %d:%02d", purge.remaining / 60, purge.remaining % 60)
                      : "Thermal cycle (3 min)", systemImage: "flame")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(purge.remaining > 0 ? Color.red : Color.secondary)
        }
        .padding(16).frame(width: 290)
    }
}
