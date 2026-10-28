//
//  HelperClient.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import Foundation
import ServiceManagement
import os
import Combine

final class HelperClient: ObservableObject {
    static let shared = HelperClient()
    @Published var alive = true
    private var conn: NSXPCConnection?

    private let log = Logger(subsystem: "ak.BatteryGuard", category: "app")

    var proxy: BatteryHelperProtocol? { remote() }

    /// Returns the helper proxy. `onError` runs if the helper can't be reached.
    func remote(onError: @escaping () -> Void = {}) -> BatteryHelperProtocol? {
        if conn == nil {
            let c = NSXPCConnection(machServiceName: kHelperMachName, options: .privileged)
            c.remoteObjectInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
            c.invalidationHandler = { [weak self] in self?.conn = nil }
            c.resume()
            conn = c
        }
        return conn?.remoteObjectProxyWithErrorHandler { [log] err in
            log.error("XPC error: \(err.localizedDescription, privacy: .public)")
            onError()
        } as? BatteryHelperProtocol
    }

    private let daemon = SMAppService.daemon(plistName: "ak.BatteryGuard.helper.plist")
    private var repairedAt: Date?

    var needsApproval: Bool { daemon.status == .requiresApproval }

    func register() {
        switch daemon.status {
        case .enabled:
            break                                   // probe() below checks it's actually running
        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
        default:
            do { try daemon.register() } catch {
                log.error("register failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        log.notice("helper status = \(self.daemon.status.rawValue)")
    }

    /// Called shortly after launch: if the helper doesn't answer, repair it.
    func ensureRunning() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.probe() }
    }

    /// Unregisters and re-registers the helper, which rebinds it to this app's current location.
    /// Rate-limited so it can't loop.
    func repairIfNeeded() {
        if let t = repairedAt, Date().timeIntervalSince(t) < 60 { return }
        repairedAt = Date()
        log.notice("helper not answering, repairing registration")
        Task { [weak self] in
            guard let self else { return }
            try? await self.daemon.unregister()
            try? self.daemon.register()
            if self.daemon.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.probe() }
        }
    }

    /// User-triggered repair (the button in the menu).
    func repair() {
        repairedAt = nil
        repairIfNeeded()
    }

    private func probe() {
        let p = remote(onError: { [weak self] in
            DispatchQueue.main.async { self?.alive = false; self?.repairIfNeeded() }
        })
        p?.status { [weak self] _, _, _ in
            DispatchQueue.main.async { self?.alive = true }
        }
    }
    
    func activity(_ message: String) {
        proxy?.appLog(message)
    }


    private var pending: (upper: Int, sailing: Bool, floor: Int)?
    private var retryScheduled = false

    func push(upper: Int, sailing: Bool, floor: Int) {
        pending = (upper, sailing, floor)
        sendPending()
    }

    private func sendPending() {
        guard let cfg = pending else { return }
        guard let p = remote(onError: { [weak self] in self?.retryLater() }) else {
            retryLater(); return
        }
        p.configure(upper: cfg.upper, sailingEnabled: cfg.sailing, floor: cfg.floor) { [weak self] ok in
            DispatchQueue.main.async {
                guard let self else { return }
                if ok {
                    self.pending = nil
                    self.alive = true
                } else {
                    self.retryLater()
                }
            }
        }
    }

    private func retryLater() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.alive = false
            guard !self.retryScheduled else { return }
            self.retryScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self else { return }
                self.retryScheduled = false
                self.sendPending()
            }
        }
    }
    
    func check() {
        _ = proxy
        let p = conn?.remoteObjectProxyWithErrorHandler { [weak self] _ in
            DispatchQueue.main.async { self?.alive = false }
        } as? BatteryHelperProtocol
        p?.status { [weak self] _, _, _ in
            DispatchQueue.main.async { self?.alive = true }
        }
    }
    
    /// At launch: if the running helper isn't the one bundled in this app, ask it to restart.
    func ensureCurrent() {
        let mine = fingerprint(of: Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/BatteryGuardHelper"))
        proxy?.build { [weak self] running in
            guard running != mine else { return }
            self?.log.notice("helper outdated (\(running, privacy: .public) vs \(mine, privacy: .public)), restarting")
            self?.proxy?.restart()
        }
    }
}

