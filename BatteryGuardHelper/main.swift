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
    private var backstop: Timer?
    private var snapshotTimer: Timer?
    private var lastCeiling: Int?
    private var holdLevel: Int?
    private var lastLogged = ""
    private var inhibiting = false
    private(set) var holding = false
    
    private var lastDumpState = ""

    // true = fell to the floor, charging back up to the limit. Stored in defaults so a
    // helper restart mid-refill doesn't stop the refill.
    private var refilling: Bool {
        get { d.bool(forKey: "refilling") }
        set { d.set(newValue, forKey: "refilling") }
    }

    var upper: Int { d.object(forKey: "upper") as? Int ?? 80 }
    var floor: Int { d.object(forKey: "floor") as? Int ?? 40 }
    var sailing: Bool { d.bool(forKey: "sailing") }

    func start() {
        ActivityLog.write("START", "helper build=\(myBuild) pid=\(getpid())")
        if d.object(forKey: "origMCL") == nil, let c = NativeLimit.current(), c >= 80 {
            d.set(c, forKey: "origMCL")
            ActivityLog.write("START", "saved Apple's own charge limit=\(c) as restore value")
        }
        SMCBattery.setLED(.system)         // clear any LED override from earlier builds
        clearInhibit("startup")            // a crashed earlier run may have left charging blocked
        
        SMCBattery.probe()
        SMCBattery.dumpChargeKeys()

        watcher = PowerWatcher { [weak self] in
            ActivityLog.write("POWER", "power source changed | \(ActivityLog.batterySnapshot())")
            self?.evaluate()
        }
        // Backstop: power notifications don't fire on every percentage step.
        backstop = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.reassert()
        }
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.logSnapshot()
        }
        logSnapshot()
        evaluate()
    }

    /// Periodic state line: battery current, Apple's limit as read back, and our decisions.
    func logSnapshot() {
        let apple = NativeLimit.current().map { "\($0)" } ?? "nil"
        let ceiling = lastCeiling.map { "\($0)" } ?? "nil"
        ActivityLog.write("SNAPSHOT", "\(ActivityLog.batterySnapshot()) appleLimit=\(apple) "
                          + "ceiling=\(ceiling) holding=\(holding) inhibit=\(inhibiting)")
    }

    /// Re-checks every minute and re-applies the ceiling if macOS has changed it.
    func reassert() {
        evaluate()
        if let want = lastCeiling {
            let actual = NativeLimit.current()
            if actual != want {
                ActivityLog.write("DRIFT", "macOS reports limit=\(actual.map { "\($0)" } ?? "nil"), we set \(want); reapplying")
                lastCeiling = nil
                evaluate()
            }
        }
    }

    /// Runs on power events, settings changes, and the 60s backstop.
    func evaluate() {
        guard let s = PowerSnapshot.read() else {
            ActivityLog.write("WARN", "could not read power source")
            return
        }
        let p = s.percent
        
        let stateKey = "ac=\(s.onAC) charging=\(s.charging)"
        if stateKey != lastDumpState {
            lastDumpState = stateKey
            ActivityLog.write("SMCKEY", "state change -> \(stateKey)")
            SMCBattery.dumpChargeKeys()
        }

        // Sailing: refill only after falling to the floor, and stop once the limit is reached.
        // Without sailing: charge while below the limit.
        if upper >= 100 {
            refilling = false
        } else if sailing {
            if p <= floor { refilling = true }
            if p >= upper { refilling = false }
        } else {
            refilling = false
        }
        let mayCharge = upper >= 100 || (sailing ? refilling : p < upper)

        // On the charger and not allowed to charge: the battery neither charges nor drains,
        // and the Mac runs from the wall. The adapter always stays connected.
        holding = s.onAC && !mayCharge

        if lastCeiling != 100 {
            if NativeLimit.set(100) { lastCeiling = 100 }    // Apple's own limit stays out of the way
        }
        updateInhibit(holding, percent: p)

        let state = "pct=\(p) ac=\(s.onAC) charging=\(s.charging) upper=\(upper) floor=\(floor) "
                  + "sailing=\(sailing) refilling=\(refilling) mayCharge=\(mayCharge) holding=\(holding)"
        if state != lastLogged {
            ActivityLog.write("DECIDE", state)
            lastLogged = state
        }
    }
    
    
    private var lastInhibitFailure = ""

    private func updateInhibit(_ want: Bool, percent p: Int) {
        guard want != inhibiting else { return }
        if SMCBattery.setInhibit(want) {
            inhibiting = want
            lastInhibitFailure = ""
            ActivityLog.write("INHIBIT", "\(want ? "ON" : "OFF") pct=\(p) sailing=\(sailing) keys=\(SMCBattery.lastPath)")
        } else if lastInhibitFailure != SMCBattery.lastPath {
            lastInhibitFailure = SMCBattery.lastPath
            ActivityLog.write("INHIBIT", "\(want ? "ON" : "OFF") FAILED pct=\(p) keys=\(SMCBattery.lastPath)")
        }
    }
    private func clearInhibit(_ reason: String) {
        let ok = SMCBattery.setInhibit(false)
        inhibiting = false
        ActivityLog.write("INHIBIT", "cleared (\(reason)) ok=\(ok) keys=\(SMCBattery.lastPath)")
    }

    /// Puts Apple's own limit back and releases any charge inhibit.
    @discardableResult
    func restoreOriginal() -> Bool {
        lastCeiling = nil; refilling = false; holdLevel = nil
        clearInhibit("restore")
        SMCBattery.setLED(.system)
        return NativeLimit.set(d.object(forKey: "origMCL") as? Int ?? 80)
    }

    // MARK: XPC
    func configure(upper: Int, sailingEnabled: Bool, floor: Int, reply: @escaping (Bool) -> Void) {
        let newFloor = min(max(floor, 20), 80)
        let newUpper = min(max(upper, 50), 100)
        ActivityLog.write("CONFIG", "from app: upper=\(upper)->\(newUpper) floor=\(floor)->\(newFloor) sailing=\(sailingEnabled)")
        if sailingEnabled != sailing || newFloor != self.floor { refilling = false }
        d.set(newUpper, forKey: "upper")
        d.set(newFloor, forKey: "floor")
        d.set(sailingEnabled, forKey: "sailing")
        lastCeiling = nil; holdLevel = nil
        evaluate(); reply(true)
    }

    func resetOverrides(reply: @escaping (Bool) -> Void) {
        ActivityLog.write("RESET", "user chose Reset SMC Overrides in the menu")
        reply(restoreOriginal())
    }

    func build(reply: @escaping (String) -> Void) { reply(myBuild) }

    func restart() {
        ActivityLog.write("RESTART", "app requested restart (newer helper build)")
        ActivityLog.flush()
        exit(0)                                   // launchd (KeepAlive) relaunches the new binary
    }

    func status(reply: @escaping (Int, Bool, Bool) -> Void) {
        let s = PowerSnapshot.read()
        reply(s?.percent ?? 0, s?.onAC ?? false, holding)
    }

    func appLog(_ message: String) {
        ActivityLog.write("APP", message)
    }

    // MARK: Connection auth
    func listener(_ l: NSXPCListener, shouldAcceptNewConnection c: NSXPCConnection) -> Bool {
        ActivityLog.write("XPC", "app connected pid=\(c.processIdentifier)")
        c.setCodeSigningRequirement(#"identifier "ak.BatteryGuard""#)
        c.exportedInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
        c.exportedObject = self
        c.resume(); return true
    }
}

let myBuild = fingerprint(of: Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
let engine = Engine()

// Crash guard: on a normal stop, put Apple's own limit back and release the inhibit
var sigSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT] {
    signal(sig, SIG_IGN)
    let s = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    s.setEventHandler {
        ActivityLog.write("STOP", "signal \(sig) received, restoring Apple's limit")
        engine.restoreOriginal()
        ActivityLog.flush()
        exit(0)
    }
    s.resume(); sigSources.append(s)
}

let listener = NSXPCListener(machServiceName: kHelperMachName)
listener.delegate = engine
listener.resume()
engine.start()
RunLoop.main.run()
