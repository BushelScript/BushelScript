import Foundation
import os

private let log = OSLog(subsystem: logSubsystem, category: "Language module management")

public class LanguageModule {
    
    public let identifier: String
    public let name: String
    
    private var bundle: Bundle
    private let types: Types
    
    private typealias Types = (
        messageFormatter: MessageFormatter.Type,
        parser: SourceParser.Type,
        formatter: SourceFormatter.Type
    )
    
    public func messageFormatter() -> MessageFormatter {
        types.messageFormatter.init()
    }
    public func parser() -> SourceParser {
        types.parser.init(translations: translations)
    }
    public func formatter() -> SourceFormatter {
        types.formatter.init()
    }
    
    public let translations: [Translation]
    
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
            os_log("Could not load language module \"%{public}@\" (identifier \"%{public}@\"): the module's declared protocol major version is incompatible", log: log, type: .info, name, identifier)
            return nil
        }
        // In v1.0 and beyond, this should *not* fail, but for now we consider
        // every minor version to be ABI-breaking
        guard (protocolMinorVersion as AnyObject).intValue == 2 else {
            os_log("Could not load language module \"%{public}@\" (identifier \"%{public}@\"): the module's declared protocol minor version is incompatible", log: log, type: .info, name, identifier)
            return nil
        }
        
        guard
            let principalClassName = infoDictionary["NSPrincipalClass"] as? String,
            let entryPoint = NSClassFromString(principalClassName) as? LanguageModuleEntryPoint.Type
        else {
            return nil
        }
        
        let moduleTypes = entryPoint.moduleTypes
        guard
            let messageFormatter = moduleTypes["MessageFormatter"] as? MessageFormatter.Type,
            let parser = moduleTypes["SourceParser"] as? SourceParser.Type,
            let formatter = moduleTypes["SourceFormatter"] as? SourceFormatter.Type
        else {
            os_log("Could not load language module \"%{public}@\" (identifier \"%{public}@\"): moduleTypes did not return all required types", log: log, type: .info, name, identifier)
            return nil
        }
        
        self.types = (
            messageFormatter: messageFormatter,
            parser: parser,
            formatter: formatter
        )
        
        self.translations =
            bundle.urls(forResourcesWithExtension: nil, subdirectory: "Translations").map { translationFileURLs in
                 translationFileURLs.compactMap { translationFileURL in
                    do {
                        let translationContents = try String(contentsOf: translationFileURL)
                        return try Translation(source: translationContents)
                    } catch {
                        os_log("Could not load translation file \"%@\" in language module \"%{public}@\": %@", log: log, error.localizedDescription)
                        return nil
                    }
                }
            } ?? []
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
        let bundleURL = bundleDirURL.appendingPathComponent("\(identifier).bundle", isDirectory: true)
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
            .filter { $0.lastPathComponent.hasSuffix(".bundle") }
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
    #if DEVENVIRONMENT
    let devEnvironmentLanguageBundleDirectories: [URL] = mainLanguageBundleDirectories.map { url in
        url.appendingPathComponent("DevEnvironment")
    }
    return devEnvironmentLanguageBundleDirectories
    #else
    return mainLanguageBundleDirectories
    #endif
}()
