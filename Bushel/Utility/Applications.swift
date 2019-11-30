import Foundation
import SwiftAutomation

extension Bundle {
    
    public convenience init?(applicationName: String) {
        signpostBegin()
        defer { signpostEnd() }
        
        guard let bundleIdentifier = TargetApplication.name(applicationName).bundleIdentifier else {
            return nil
        }
        self.init(applicationBundleIdentifier: bundleIdentifier)
    }
    
    public convenience init?(applicationBundleIdentifier: String) {
        signpostBegin()
        defer { signpostEnd() }
        
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: applicationBundleIdentifier) else {
            return nil
        }
        self.init(url: url)
    }
    
}
