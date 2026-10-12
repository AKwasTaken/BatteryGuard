//
//  Fingerprint.swift
//  BatteryGuard
//
//  Created by Aneeth Kumaar on 12/10/26.
//


import Foundation
import CryptoKit

func fingerprint(of url: URL) -> String {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return "?" }
    return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
}
