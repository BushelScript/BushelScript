import Foundation
import os

private let log = OSLog(subsystem: logSubsystem, category: "Language module management")

public class LanguageModule {
    
    public let identifier: String
    public let name: String
    
    private var bundle: Bundle
    private let types: Types
    
    private typealias Types = (
        parser: SourceParser.Type,
        formatter: SourceFormatter.Type
    )
    
    public func parser() -> SourceParser {
        return types.parser.init()
    }
    public func formatter() -> SourceFormatter {
        return types.formatter.init()
    }
    
    public init?(identifier: String) {
        guard
            let bundle = languageBundle(for: identifier),
            let infoDictionary = bundle.infoDictionary,
            let name = infoDictionary[kCFBundleNameKey as String] as? String,
            let protocolVersion = infoDictionary["BushelLanguageModuleProtocolVersion"] as? [String : Any],
            let protocolMajorVersion = protocolVersion["Major"],
            let protocolMinorVersion = protocolVersion["Minor"],
            bundle.load()
        else {
            return nil
        }
        
        self.bundle = bundle
        self.identifier = identifier
        self.name = name
        
        guard (protocolMajorVersion as AnyObject).intValue == 0 else {
            os_log("Could not load language module \"%{public}@\" (identifier \"%{public}@\"): the module's declared protocol version is incompatible", log: log, type: .info, name, identifier)
            return nil
        }
        _ = protocolMinorVersion // To be used in the future to e.g. add new non-breaking APIs
        
        guard
            let principalClassName = infoDictionary["NSPrincipalClass"] as? String,
            let entryPoint = NSClassFromString(principalClassName) as? LanguageModuleEntryPoint.Type
        else {
            return nil
        }
        
        let moduleTypes = entryPoint.moduleTypes
        guard
            let parser = moduleTypes["SourceParser"] as? SourceParser.Type,
            let formatter = moduleTypes["SourceFormatter"] as? SourceFormatter.Type//,
//            let messageFormatter = moduleTypes["MessageFormatter"] as? MessageFormatter.Type
        else {
            os_log("Could not load language module \"%{public}@\" (identifier \"%{public}@\"): moduleTypes did not return all required types", log: log, type: .info, name, identifier)
            return nil
        }
        
        self.types = (
            parser: parser,
            formatter: formatter
        )
    }
    
    public struct ModuleDescriptor {
        
        public var identifier: String
        public var localizedName: String
        
        // TODO: Add an init to LanguageModule that takes one of these for efficiency
        //       This property would then be used
        private var bundleURL: URL
        
        fileprivate init(bundle: Bundle) {
            self.bundleURL = bundle.bundleURL
            let identifier = bundle.bundleURL.deletingPathExtension().lastPathComponent
            self.identifier = identifier
            self.localizedName = (bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? identifier
        }
        
    }
    
    public static func validModules() -> [ModuleDescriptor] {
        return allLanguageBundles().map { ModuleDescriptor(bundle: $0) }
    }
    
}

@objc public protocol LanguageModuleEntryPoint {
    
    static var moduleTypes: [String : Any] { get }
    
}

private func languageBundle(for identifier: String) -> Bundle? {
    for bundleDirURL in languageBundleDirectories {
        let bundleURL = bundleDirURL.appendingPathComponent("\(identifier).framework", isDirectory: true)
        if let bundle = Bundle(url: bundleURL) {
            return bundle
        }
    }
    return nil
}

private func allLanguageBundles() -> [Bundle] {
    return languageBundleDirectories.flatMap { bundleDirURL in
        return (try?
            FileManager.default.contentsOfDirectory(at: bundleDirURL, includingPropertiesForKeys: nil, options: [])
            .filter { $0.lastPathComponent.hasSuffix(".framework") }
            .compactMap { return Bundle(url: $0) }
        ) ?? []
    }
}

private var languageBundleDirectories: [URL] = {
    let libraryURLs = FileManager.default.urls(for: .libraryDirectory, in: .allDomainsMask)
    let mainLanguageBundleDirectories = libraryURLs.map { url in
        url
            .appendingPathComponent("BushelScript", isDirectory: true)
            .appendingPathComponent("Languages", isDirectory: true)
    }
    #if DEBUG
    let devEnvironmentLanguageBundleDirectories: [URL] = mainLanguageBundleDirectories.map { url in
        url.appendingPathComponent("DevEnvironment")
    }
    return devEnvironmentLanguageBundleDirectories
    #else
    return mainLanguageBundleDirectories
    #endif
}()
