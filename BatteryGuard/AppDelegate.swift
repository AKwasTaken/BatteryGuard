//
//  AppDelegate.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let model = BatteryModel()

    func applicationDidFinishLaunching(_ n: Notification) {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ControlPanel().environmentObject(model))

        if let b = item.button {
            b.target = self
            b.action = #selector(clicked(_:))
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])      // Enables dual click
        }
        model.onChange = { [weak self] in self?.refreshIcon() }
        refreshIcon()
        HelperClient.shared.register()
        
        let d = UserDefaults.standard
        HelperClient.shared.push(upper: Int(d.object(forKey: "upper") as? Double ?? 80),
                                 sailing: d.bool(forKey: "sailing"),
                                 floor: Int(d.object(forKey: "floor") as? Double ?? 40))
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp { 
            showMenu(sender) 
        } else if popover.isShown { 
            popover.performClose(nil) 
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu(_ sender: NSStatusBarButton) {
        popover.performClose(nil)

        let m = NSMenu()
        
        let login = m.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        
        let reset = m.addItem(withTitle: "Reset SMC Overrides", action: #selector(resetSMC), keyEquivalent: "")
        reset.target = self
        
        m.addItem(.separator())
        
        let about = m.addItem(withTitle: "About", action: #selector(openAbout), keyEquivalent: "")
        about.target = self

        let quit = m.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self

        item.menu = m
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About BatteryGuard"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: AboutView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.aboutWindow = window
    }

    @objc private func resetSMC() { HelperClient.shared.proxy?.resetOverrides { _ in } }
    @objc private func toggleLogin() {
        let s = SMAppService.mainApp
        try? (s.status == .enabled ? s.unregister() : s.register())
    }
    private var aboutWindow: NSWindow?
    @objc private func quit() {
        AntPurge.shared.stop()
        NSApp.terminate(nil) 
    }

    private func refreshIcon() {
        guard let b = item.button else { return }
        b.image = BatteryIcon.make(percent: model.percent, bolt: model.onAC)
        b.imagePosition = .imageLeft
        b.attributedTitle = NSAttributedString(
            string: " \(model.percent)%",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)])
    }
}
