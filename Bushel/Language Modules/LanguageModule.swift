import Foundation
import os

private let log = OSLog(subsystem: logSubsystem, category: "Language module management")

public final class LanguageModule {
    
    public let descriptor: Descriptor
    
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
    
    public convenience init(identifier: String) throws {
        guard let bundle = languageBundle(for: identifier) else {
            throw NoSuchLanguageModule(languageID: identifier)
        }
        try self.init(Descriptor(bundle: bundle))
    }
    
    fileprivate init(_ descriptor: Descriptor) throws {
        self.descriptor = descriptor
        
        let bundle = descriptor.bundle
        guard
            let infoDictionary = bundle.infoDictionary,
            let protocolVersion = infoDictionary["BushelLanguageModuleProtocolVersion"] as? [String : Any],
            let protocolMajorVersion = protocolVersion["Major"] as AnyObject?,
            let protocolMinorVersion = protocolVersion["Minor"] as AnyObject?
        else {
            throw LanguageModuleInvalid(descriptor: descriptor, reason: "Failed to read BushelLanguageModuleProtocolVersion")
        }
        
        let expectedMajor = 0, expectedMinor = 3
        
        guard let major: Int = protocolMajorVersion.intValue, major == expectedMajor else {
            throw LanguageModuleInvalid(descriptor: descriptor, reason: "Incompatible or invalid major protocol version (expecting \(expectedMajor)")
        }
        // In v1.0 and beyond, this should only fail if greater than the current minor version,
        // but for now we consider every minor version to be ABI-breaking.
        guard let minor: Int = protocolMinorVersion.intValue, minor == expectedMinor else {
            throw LanguageModuleInvalid(descriptor: descriptor, reason: "Incompatible or invalid minor protocol version (expecting \(expectedMinor)")
        }
        
        guard bundle.load() else {
            throw LanguageModuleInvalid(descriptor: descriptor, reason: "Failed to load code")
        }
        
        guard let principalClassName = infoDictionary["NSPrincipalClass"] as? String else {
            throw LanguageModuleInvalid(descriptor: descriptor, reason: "No NSPrincipalClass declared")
        }
        guard let entryPoint = NSClassFromString(principalClassName) as? LanguageModuleEntryPoint.Type else {
            throw LanguageModuleInvalid(descriptor: descriptor, reason: "Declared NSPrincipalClass is not a LanguageModuleEntryPoint")
        }
        
        let moduleTypes = entryPoint.moduleTypes
        guard
            let messageFormatter = moduleTypes["MessageFormatter"] as? MessageFormatter.Type,
            let parser = moduleTypes["SourceParser"] as? SourceParser.Type,
            let formatter = moduleTypes["SourceFormatter"] as? SourceFormatter.Type
        else {
            throw LanguageModuleInvalid(descriptor: descriptor, reason: "Required interface(s) not implemented (moduleTypes did not return all required types)")
        }
        
        self.types = (
            messageFormatter: messageFormatter,
            parser: parser,
            formatter: formatter
        )
        
        self.translations =
            try bundle.urls(forResourcesWithExtension: nil, subdirectory: "Translations").map { translationFileURLs in
                 try translationFileURLs.map(Translation.init(from:))
            } ?? []
    }
    
    public struct Descriptor {
        
        public var bundle: Bundle
        public var identifier: String
        public var localizedName: String
        
        fileprivate init(bundle: Bundle) {
            self.bundle = bundle
            let identifier = bundle.bundleURL.deletingPathExtension().lastPathComponent
            self.identifier = identifier
            self.localizedName = (bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String) ?? identifier
        }
        
    }
    
    public static func validModules() -> [Descriptor] {
        return allLanguageBundles().map { Descriptor(bundle: $0) }
    }
    
}

public struct NoSuchLanguageModule: LocalizedError {
    
    public var languageID: String
    
    public init(languageID: String) {
        self.languageID = languageID
    }
    
    public var errorDescription: String? {
        "No valid language module found for ID \(languageID)"
    }
    
}

public struct LanguageModuleInvalid: LocalizedError {
    
    public var descriptor: LanguageModule.Descriptor
    public var reason: String
    
    public var errorDescription: String? {
        "Invalid language module with ID \(descriptor.identifier) at \(descriptor.bundle.bundlePath): \(reason)"
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
