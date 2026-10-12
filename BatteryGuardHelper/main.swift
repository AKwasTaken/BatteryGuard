//
//  main.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import Foundation
import os

final class Engine: NSObject, NSXPCListenerDelegate, BatteryHelperProtocol {
    private let d = UserDefaults.standard
    private let log = Logger(subsystem: "ak.BatteryGuard", category: "helper")
    private var watcher: PowerWatcher?
    private var refilling = false          // true = fell to the floor, charging back up to the limit
    private var lastCeiling: Int?
    private(set) var holding = false

    var upper: Int { d.object(forKey: "upper") as? Int ?? 80 }
    var floor: Int { d.object(forKey: "floor") as? Int ?? 40 }
    var sailing: Bool { d.bool(forKey: "sailing") }

    func start() {
        // Remember your normal Apple charge limit (Apple's slider only allows 80-100)
        if d.object(forKey: "origMCL") == nil, let c = NativeLimit.current(), c >= 80 {
            d.set(c, forKey: "origMCL")
        }
        SMCBattery.setLED(.system)         // clear any LED override from earlier builds
        watcher = PowerWatcher { [weak self] in self?.evaluate() }
        evaluate()
    }

    /// Runs only on power events and settings changes.
    func evaluate() {
        guard let s = PowerSnapshot.read() else { return }
        let p = s.percent
        let target: Int

        if upper >= 100 {
            target = 100; refilling = false
        } else if p >= upper {
            target = p; refilling = false             // at/above the limit: hold here, never drain
        } else if !sailing {
            target = upper; refilling = false         // sailing off: always top up to the limit
        } else {
            if p <= floor { refilling = true }        // fell to the floor: refill to the limit
            target = refilling ? upper : p            // inside the range: hold where we are
        }

        holding = target <= p
        if target != lastCeiling {
            if NativeLimit.set(target) { lastCeiling = target }
            log.notice("pct=\(p) upper=\(self.upper) floor=\(self.floor) sailing=\(self.sailing) target=\(target) holding=\(self.holding)")
        }
    }

    @discardableResult
    func restoreOriginal() -> Bool {
        lastCeiling = nil; refilling = false
        SMCBattery.setLED(.system)
        return NativeLimit.set(d.object(forKey: "origMCL") as? Int ?? 80)
    }

    // MARK: XPC
    func configure(upper: Int, sailingEnabled: Bool, floor: Int, reply: @escaping (Bool) -> Void) {
        if sailingEnabled != sailing { refilling = false }
        d.set(min(max(upper, 50), 100), forKey: "upper")
        d.set(min(max(floor, 20), 80), forKey: "floor")
        d.set(sailingEnabled, forKey: "sailing")
        lastCeiling = nil                              // force a fresh write
        evaluate(); reply(true)
    }
    func resetOverrides(reply: @escaping (Bool) -> Void) { reply(restoreOriginal()) }
    func status(reply: @escaping (Int, Bool, Bool) -> Void) {
        let s = PowerSnapshot.read(); reply(s?.percent ?? 0, s?.onAC ?? false, holding)
    }

    // MARK: Connection auth
    func listener(_ l: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
        c.setCodeSigningRequirement(#"identifier "ak.BatteryGuard""#)
        c.exportedInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
        c.exportedObject = self
        c.resume(); return true
    }
}

let engine = Engine()

// Crash guard: on a normal stop, put Apple's own limit back
var sigSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    s.setEventHandler { engine.restoreOriginal(); exit(0) }
    s.resume(); sigSources.append(s)
}

let listener = NSXPCListener(machServiceName: kHelperMachName)
listener.delegate = engine
listener.resume()
engine.start()
RunLoop.main.run()
