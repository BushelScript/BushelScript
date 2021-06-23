import Foundation
import AEthereal
import os.log

private let log = OSLog(subsystem: logSubsystem, category: "Resource location")

extension Bundle {
    
    public convenience init?(applicationName: String) {
        signpostBegin()
        defer { signpostEnd() }
        
        guard let bundleIdentifier = AETarget.name(applicationName).bundleIdentifier else {
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

public func findNativeLibrary(named libraryName: String, ignoring: Set<URL>) -> (url: URL, library: Library)? {
    signpostBegin()
    defer { signpostEnd() }
    
    for libraryDirURL in scriptLibraryDirectories {
        let validExtensions = ["bushel"]
        let libraryURLs = validExtensions.map { `extension` in
            libraryDirURL.appendingPathComponent("\(libraryName).\(`extension`)")
        }
        
        for libraryURL in libraryURLs where !ignoring.contains(libraryURL) {
            do {
                // Likely to throw.
                let program = try parse(from: libraryURL, ignoringImports: ignoring)
                
                os_log("Found native library at %@", log: log, type: .debug, libraryURL as NSURL)
                return (url: libraryURL, library: .native(program))
            } catch {
                os_log("No valid native library at %@: %@", log: log, type: .debug, libraryURL as NSURL, error as NSError)
            }
        }
    }
    
    os_log("Failed to find native library with name '%@'", log: log, type: .debug, libraryName)
    return nil
}

public func findAppleScriptLibrary(named libraryName: String) -> (url: URL, library: Library)? {
    signpostBegin()
    defer { signpostEnd() }
    
    for libraryDirURL in applescriptLibraryDirectories {
        let validExtensions = ["applescript", "scpt", "scptd"]
        let libraryURLs = validExtensions.map { `extension` in
            libraryDirURL.appendingPathComponent("\(libraryName).\(`extension`)")
        }
        
        for libraryURL in libraryURLs {
            if let applescript = NSAppleScript(contentsOf: libraryURL, error: nil) {
                os_log("Found AppleScript library at %@", log: log, type: .debug, libraryURL as NSURL)
                return (url: libraryURL, library: .applescript(applescript))
            }
        }
    }

    os_log("Failed to find AppleScript library with name '%@'", log: log, type: .debug, libraryName)
    return nil
}

private var scriptLibraryDirectories: [URL] = {
    let appBundleLibraryDirs = LanguageModule.appBundle?
        .url(forResource: "Libraries", withExtension: nil)
        .map { [$0] } ?? []
    let libraryURLs = FileManager.default.urls(for: .libraryDirectory, in: .allDomainsMask)
    return appBundleLibraryDirs + libraryURLs.map { url in
        url
            .appendingPathComponent("BushelScript", isDirectory: true)
            .appendingPathComponent("Libraries", isDirectory: true)
    }
}()
    
private var applescriptLibraryDirectories: [URL] = {
    let libraryURLs = FileManager.default.urls(for: .libraryDirectory, in: .allDomainsMask)
    return scriptLibraryDirectories + libraryURLs.map { url in
        url
            .appendingPathComponent("Script Libraries", isDirectory: true)
    }
}()
