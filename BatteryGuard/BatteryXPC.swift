//
//  BatteryXPC.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//

import Foundation

let kHelperMachName = "ak.BatteryGuard.helper"

@objc protocol BatteryHelperProtocol {
    func configure(upper: Int, sailingEnabled: Bool, floor: Int, reply: @escaping (Bool) -> Void)
    func resetOverrides(reply: @escaping (Bool) -> Void)
    func status(reply: @escaping (_ percent: Int, _ onAC: Bool, _ inhibited: Bool) -> Void)
    
    func build(reply: @escaping (String) -> Void)
    func restart()
    
    func appLog(_ message: String)
}
