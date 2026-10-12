//
//  HelperClient.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import Foundation
import ServiceManagement
import os

final class HelperClient {
    static let shared = HelperClient()
    private var conn: NSXPCConnection?

    private let log = Logger(subsystem: "ak.BatteryGuard", category: "app")

    var proxy: BatteryHelperProtocol? {
        if conn == nil {
            let c = NSXPCConnection(machServiceName: kHelperMachName, options: .privileged)
            c.remoteObjectInterface = NSXPCInterface(with: BatteryHelperProtocol.self)
            c.invalidationHandler = { [weak self] in self?.conn = nil }
            c.resume()
            conn = c
        }
        return conn?.remoteObjectProxyWithErrorHandler { [log] err in
            log.error("XPC error: \(err.localizedDescription, privacy: .public)")
        } as? BatteryHelperProtocol
    }

    func register() {
        let svc = SMAppService.daemon(plistName: "ak.BatteryGuard.helper.plist")
        
        if svc.status == .notRegistered || svc.status == .notFound {
            do {
                try svc.register()
            } catch {
                log.error("register failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        // Re-check status: if macOS queued it for user approval, open the panel directly
        if svc.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        
        log.notice("helper status = \(svc.status.rawValue)") // 0 none, 1 enabled, 2 needs approval, 3 not found
    }


    func push(upper: Int, sailing: Bool, floor: Int) {
        proxy?.configure(upper: upper, sailingEnabled: sailing, floor: floor) { _ in }
    }
}

