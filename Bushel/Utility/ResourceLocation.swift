import Foundation
import SwiftAutomation
import os.log

private let log = OSLog(subsystem: logSubsystem, category: "Resource location")

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

public func findAppleScriptLibrary(named libraryName: String) -> (url: URL, applescript: NSAppleScript)? {
    signpostBegin()
    defer { signpostEnd() }
    
    for libraryDirURL in scriptLibraryDirectories {
        let validExtensions = ["applescript", "scpt", "scptd"]
        let libraryURLs = validExtensions.map { `extension` in
            libraryDirURL.appendingPathComponent("\(libraryName).\(`extension`)")
        }
        
        for libraryURL in libraryURLs {
            if let applescript = NSAppleScript(contentsOf: libraryURL, error: nil) {
                os_log("Found AppleScript library at %@", log: log, type: .debug, libraryURL as NSURL)
                return (url: libraryURL, applescript: applescript)
            }
        }
    }

    os_log("Failed to find AppleScript library with name '%@'", log: log, type: .debug, libraryName)
    return nil
}
    
private var scriptLibraryDirectories: [URL] = {
    let libraryURLs = FileManager.default.urls(for: .libraryDirectory, in: .allDomainsMask)
    return libraryURLs.flatMap { url in
        [
            url
                .appendingPathComponent("BushelScript", isDirectory: true)
                .appendingPathComponent("Libraries", isDirectory: true),
            url
                .appendingPathComponent("Script Libraries", isDirectory: true)
        ]
    }
}()
