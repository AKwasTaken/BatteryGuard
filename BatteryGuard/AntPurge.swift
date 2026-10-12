//
//  AntPurge.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import Foundation
import Combine
import os

@inline(never) private func sink(_ x: Float) { if x == .infinity { print("") } }   // defeats dead-code elimination

final class AntPurge: ObservableObject {
    static let shared = AntPurge()
    static let duration = 180

    @Published private(set) var remaining = 0               // 0 = idle
    private let cancelled = OSAllocatedUnfairLock(initialState: false)
    private var failsafe: DispatchSourceTimer?
    private var ticker: Timer?
    private var activity: NSObjectProtocol?
    private var deadline = Date()

    func start(seconds: Int = AntPurge.duration) {
        guard remaining == 0 else { return }
        cancelled.withLock { $0 = false }
        deadline = Date().addingTimeInterval(Double(seconds))
        remaining = seconds
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled], reason: "Ant Purge")

        let end = deadline, flag = cancelled
        for _ in 0..<ProcessInfo.processInfo.activeProcessorCount {
            let t = Thread {
                let c = SIMD8<Float>(repeating: 1e-7)
                while !flag.withLock({ $0 }) && Date() < end {          // guard #1: worker self-checks
                    var v = SIMD8<Float>(repeating: 1.0001)             // reset per batch so it never overflows
                    for _ in 0..<2_000_000 { v = v.addingProduct(v, c) }   // NEON FMA: saturates the cores
                    sink(v[0])
                }
            }
            t.qualityOfService = .userInteractive                        // P-cores first
            t.name = "AntPurge"
            t.start()
        }

        // guard #2: independent hard shutoff
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(seconds))
        timer.setEventHandler { [weak self] in self?.stop() }
        timer.resume(); failsafe = timer

        // guard #3: 1 Hz UI tick + thermal-critical abort
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.remaining = max(0, Int(self.deadline.timeIntervalSinceNow.rounded(.up)))
            if self.remaining == 0 || ProcessInfo.processInfo.thermalState == .critical { self.stop() }
        }
    }

    func stop() {
        cancelled.withLock { $0 = true }
        failsafe?.cancel(); failsafe = nil
        ticker?.invalidate(); ticker = nil
        if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }
        remaining = 0
    }
}
