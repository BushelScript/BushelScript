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
    
    public convenience init?(scriptingAdditionName: String) {
        signpostBegin()
        defer { signpostEnd() }
        
        let libraryDirs = FileManager.default.urls(for: .libraryDirectory, in: .allDomainsMask)
        let osaxDirs = libraryDirs.map { $0.appendingPathComponent("ScriptingAdditions", isDirectory: true) }
        
        for osaxDir in osaxDirs {
            var osaxURL = osaxDir.appendingPathComponent(scriptingAdditionName)
            if osaxURL.pathExtension != "osax" {
                osaxURL.appendPathExtension("osax")
            }
            
            if Bundle(url: osaxURL) != nil {
                self.init(url: osaxURL)
                return
            }
        }
        return nil
    }
    
    public var fileSystemName: String {
        bundleURL.deletingPathExtension().lastPathComponent
    }
    
}
