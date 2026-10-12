//
//  BatteryGuardApp.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//

import SwiftUI

@main struct BatteryGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
