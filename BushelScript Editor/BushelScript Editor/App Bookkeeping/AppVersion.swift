// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Foundation

enum AppVersion: String {
    
    static let current = AppVersion.v0_2
    
    case v0_2
    
}

extension AppVersion: Codable {
}
