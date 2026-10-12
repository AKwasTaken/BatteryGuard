//
//  BatteryModel.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import Foundation
import Combine

final class BatteryModel: ObservableObject {
    @Published var percent: Int = 0
    @Published var onAC: Bool = false
    @Published var charging: Bool = false
    
    var onChange: (() -> Void)?
    private var watcher: PowerWatcher?
    
    private var timer: Timer?
    
    init() {
        watcher = PowerWatcher { [weak self] in
            self?.refresh()
        }
        refresh()
    }
    
    func refresh() {
        if let s = PowerSnapshot.read() {
            percent = s.percent
            onAC = s.onAC
            charging = s.charging
        }
        onChange?()
    }
    
    func startFastRefresh() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func stopFastRefresh() { timer?.invalidate(); timer = nil }
}
