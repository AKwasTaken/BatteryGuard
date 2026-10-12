//
//  RangePill.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//

import SwiftUI

struct RangePill: View {
    @Binding var floor: Double
    @Binding var limit: Double
    var level: Double
    var sailing: Bool
    var onCommit: () -> Void

    // Slimmer track and precise indicator proportions
    private let trackHeight: CGFloat = 14
    private let barHeight: CGFloat = 22      // Extends 4pt above & below the track
    private let barWidth: CGFloat = 2.5      // Crisp, thin indicator line

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let progressWidth = (CGFloat(level) / 100.0) * w

            ZStack(alignment: .leading) {
                // Background track & battery fill
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: trackHeight)

                    Rectangle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: max(0, min(w, progressWidth)), height: trackHeight)
                }
                .clipShape(Capsule())

                // Sailing floor indicator (Blue)
                indicator(
                    color: .blue,
                    value: floor,
                    width: w,
                    dim: !sailing
                )
                .allowsHitTesting(sailing)
                .gesture(drag(w) { v in
                    floor = min(max(v, 20), min(80, limit - 5))
                })

                // Upper limit indicator (Orange)
                indicator(
                    color: .orange,
                    value: limit,
                    width: w,
                    dim: false
                )
                .gesture(drag(w) { v in
                    limit = min(max(v, 50, floor + 5), 100)
                })
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .coordinateSpace(name: "pill")
        }
        .frame(height: barHeight + 4) // Outer container reserves room for vertical overhang
    }

    private func indicator(color: Color, value: Double, width: CGFloat, dim: Bool) -> some View {
        let xPos = (CGFloat(value) / 100.0) * width

        return ZStack {
            // Visual line
            Capsule()
                .fill(color)
                .frame(width: barWidth, height: barHeight)
                .shadow(color: Color.black.opacity(0.3), radius: 1, y: 0.5)
                .opacity(dim ? 0.35 : 1.0)

            // Invisible expanded hit area for smooth dragging
            Rectangle()
                .fill(Color.clear)
                .frame(width: 24, height: barHeight + 10)
                .contentShape(Rectangle())
        }
        .position(x: min(max(xPos, barWidth / 2), width - barWidth / 2), y: (barHeight + 4) / 2)
    }

    private func drag(_ width: CGFloat, _ set: @escaping (Double) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("pill"))
            .onChanged { g in
                let raw = Double(g.location.x / width) * 100.0
                set((raw / 5.0).rounded() * 5.0) // Snaps to 5% increments
            }
            .onEnded { _ in
                onCommit()
            }
    }
}
