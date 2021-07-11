import Foundation
import Regex

public enum Resource {
    
    case bushelscript
    case system(version: String?)
    case applicationByName(bundle: Bundle)
    case applicationByID(bundle: Bundle)
    case libraryByName(name: String, url: URL, library: Library)
    case applescriptAtPath(path: String, script: NSAppleScript)
    
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
    
    public struct System {
        
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
        case .libraryByName(let name, _, _):
            return name
        case .applescriptAtPath(let path, _):
            return path
        }
    }
    
}

// MARK: String → Resource
extension Resource {
    
    public init?(normalized: String, cache: ResourceCache) {
        let components = normalized.split(separator: ":", maxSplits: 1)
        guard
            components.indices.contains(0),
            let kind = Kind(rawValue: String(components[0]))
        else {
            return nil
        }
        self.init(kind: kind, data: components.indices.contains(1) ? String(components[1]) : "", cache: cache)
    }
    
    public init?(kind: Kind, data: String, cache: ResourceCache) {
        guard
            let resolved: Resource = try? {
                switch kind {
                case .bushelscript:
                    return .bushelscript
                case .system:
                    return System().enumerated()
                case .applicationByName:
                    return try cache.app(named: data).map { .applicationByName(bundle: $0) }
                case .applicationByID:
                    return try cache.app(id: data).map { .applicationByID(bundle: $0) }
                case .libraryByName:
                    return try cache.library(named: data, ignoring: []).map { .libraryByName(name: data, url: $0.url, library: $0.library) }
                case .applescriptAtPath:
                    return try cache.applescript(at: data).map { .applescriptAtPath(path: data, script: $0) }
                }
            }()
        else {
            return nil
        }
        self = resolved
    }
    
}

// MARK: Resource URL
extension Resource {
    
    public var url: URL? {
        switch self {
        case .bushelscript:
            return nil
        case .system(_):
            return Bundle(applicationBundleIdentifier: "com.apple.systemevents")?.bundleURL
        case let .applicationByName(bundle),
             let .applicationByID(bundle):
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
