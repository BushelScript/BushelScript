import Foundation
import Regex

public enum Resource {
    
    case bushelscript
    case system(version: String?)
    case applicationByName(bundle: Bundle)
    case applicationByID(bundle: Bundle)
    case scriptingAdditionByName(bundle: Bundle)
    case libraryByName(name: String, url: URL, library: Library)
    case applescriptAtPath(path: String, script: NSAppleScript)
    
}

public protocol ResolvedResource {
    
    func enumerated() -> Resource
    
}

extension OperatingSystemVersion: CustomStringConvertible {
    
    public var description: String {
        "\(majorVersion).\(minorVersion).\(patchVersion)"
    }
    
}

public enum Library {
    
    case native(Program)
    case applescript(NSAppleScript)
    
}

// MARK: Resource resolution
extension Resource {
    
    public struct BushelScript: ResolvedResource {
        
        public init() {
        }
        
        public func enumerated() -> Resource {
            .bushelscript
        }
        
    }
    
    public struct System: ResolvedResource {
        
        public let version: OperatingSystemVersion?
        
        public init?(versionString: String) {
            guard !versionString.isEmpty else {
                self.init()
                return
            }
            
            guard let match = Regex("[vV]?(\\d+)\\.(\\d+)(?:\\.(\\d+))?").firstMatch(in: versionString) else {
                return nil
            }
            
            let versionComponents = match.captures.compactMap { $0.map { Int($0)! } }
            let majorVersion = versionComponents[0]
            let minorVersion = versionComponents[1]
            let patchVersion = versionComponents.indices.contains(2) ? versionComponents[2] : 0
            
            let version = OperatingSystemVersion(majorVersion: majorVersion, minorVersion: minorVersion, patchVersion: patchVersion)
            self.init(version: version)
        }
        public init?(version: OperatingSystemVersion?) {
            if let version = version {
                guard ProcessInfo.processInfo.isOperatingSystemAtLeast(version) else {
                    return nil
                }
            }
            
            self.version = version
        }
        public init() {
            self.version = nil
        }
        
        public func enumerated() -> Resource {
            .system(version: version.map { "\($0)" })
        }
        
    }
    
    public struct ApplicationByName: ResolvedResource {
        
        public let bundle: Bundle
        
        public init?(name: String) {
            guard let bundle = Bundle(applicationName: name) else {
                return nil
            }
            
            self.bundle = bundle
        }
        
        public func enumerated() -> Resource {
            .applicationByName(bundle: bundle)
        }
        
    }
    
    public struct ApplicationByID: ResolvedResource {
        
        public let bundle: Bundle
        
        public init?(id: String) {
            guard let bundle = Bundle(applicationBundleIdentifier: id) else {
                return nil
            }
            
            self.bundle = bundle
        }
        
        public func enumerated() -> Resource {
            .applicationByID(bundle: bundle)
        }
        
    }
    
    public struct ScriptingAdditionByName: ResolvedResource {
        
        public let bundle: Bundle
        
        public init?(name: String) {
            guard let bundle = Bundle(scriptingAdditionName: name) else {
                return nil
            }
            
            self.bundle = bundle
        }
        
        public func enumerated() -> Resource {
            .scriptingAdditionByName(bundle: bundle)
        }
        
    }
    
    public struct LibraryByName: ResolvedResource {
        
        public let name: String
        public let url: URL
        public let library: Library
        
        public init?(name: String, ignoring: Set<URL>) {
            guard let (url, library) =
                findNativeLibrary(named: name, ignoring: ignoring) ??
                findAppleScriptLibrary(named: name)
            else {
                return nil
            }
            
            self.name = name
            self.url = url
            self.library = library
        }
        
        public func enumerated() -> Resource {
            .libraryByName(name: name, url: url, library: library)
        }
        
    }
    
    public struct AppleScriptAtPath: ResolvedResource {
        
        public let path: String
        public let script: NSAppleScript
        
        public init?(path: String) {
            let fileURL = URL(fileURLWithPath: path)
            guard let script = NSAppleScript(contentsOf: fileURL, error: nil) else {
                return nil
            }
            
            self.path = path
            self.script = script
        }
        
        public func enumerated() -> Resource {
            .applescriptAtPath(path: path, script: script)
        }
        
    }
    
}

// MARK: Resource → String
extension Resource: CustomStringConvertible {
    
    public var description: String {
        normalized
    }
    
    public var normalized: String {
        "\(kind):\(data)"
    }
    
    public enum Kind: String {
        case bushelscript
        case system
        case applicationByName = "app"
        case applicationByID = "appid"
        case scriptingAdditionByName = "osax"
        case libraryByName = "library"
        case applescriptAtPath = "as"
    }
    
    public var kind: Kind {
        switch self {
        case .bushelscript:
            return .bushelscript
        case .system:
            return .system
        case .applicationByName:
            return .applicationByName
        case .applicationByID:
            return .applicationByID
        case .scriptingAdditionByName:
            return .scriptingAdditionByName
        case .libraryByName:
            return .libraryByName
        case .applescriptAtPath:
            return .applescriptAtPath
        }
    }
    
    public var data: String {
        switch self {
        case .bushelscript,
             .system:
            return ""
        case .applicationByName(let bundle):
            return bundle.fileSystemName
        case .applicationByID(let bundle):
            return bundle.bundleIdentifier!
        case .scriptingAdditionByName(let bundle):
            return bundle.fileSystemName
        case .libraryByName(let name, _, _):
            return name
        case .applescriptAtPath(let path, _):
            return path
        }
    }
    
}

// MARK: String → Resource
extension Resource {
    
    public init?(normalized: String) {
        let components = normalized.split(separator: ":", maxSplits: 1)
        guard
            components.indices.contains(0),
            let kind = Kind(rawValue: String(components[0]))
        else {
            return nil
        }
        self.init(kind: kind, data: components.indices.contains(1) ? String(components[1]) : "")
    }
    
    public init?(kind: Kind, data: String) {
        guard
            let resolved: ResolvedResource = { () -> ResolvedResource? in
                switch kind {
                case .bushelscript:
                    return BushelScript()
                case .system:
                    return System()
                case .applicationByName:
                    return ApplicationByName(name: data)
                case .applicationByID:
                    return ApplicationByID(id: data)
                case .scriptingAdditionByName:
                    return ScriptingAdditionByName(name: data)
                case .libraryByName:
                    return LibraryByName(name: data, ignoring: [])
                case .applescriptAtPath:
                    return AppleScriptAtPath(path: data)
                }
            }()
        else {
            return nil
        }
        
        self = resolved.enumerated()
    }
    
}

// MARK: Resource URL
extension Resource {
    
    public var url: URL? {
        switch self {
        case .bushelscript:
            return nil
        case .system(_):
            return ApplicationByID(id: "com.apple.systemevents")?.bundle.bundleURL
        case let .applicationByName(bundle),
             let .applicationByID(bundle),
             let .scriptingAdditionByName(bundle):
            return bundle.bundleURL
        case let .libraryByName(_, url, _):
            return url
        case let .applescriptAtPath(path, _):
            return URL(fileURLWithPath: path)
        }
    }
    
}

extension TermDictionaryCache {
    
    public func loadResourceDictionary(for term: Term) throws {
        if let resourceURL = term.resource?.url {
            try load(from: resourceURL, into: term.dictionary)
        }
    }
    
}
