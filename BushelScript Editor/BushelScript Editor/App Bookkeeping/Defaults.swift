import Foundation
import Defaults

extension Defaults.Keys {
    
    static let sourceCodeFont = NSSecureCodingKey<NSFont>("SourceCodeFont", default: NSFont(name: "Menlo", size: 12) ?? NSFont.systemFont(ofSize: -1))
    static let prettyPrintBeforeRunning = Key<Bool>("PrettyPrintBeforeRunning", default: false)
    
    static let liveParsingEnabled = Key<Bool>("EnableLiveParsing", default: true)
    static let smartSuggestionsEnabled = Key<Bool>("EnableSmartSuggestions", default: true)
    static let smartSuggestionKinds = Key<[String : Bool]>("SmartSuggestionKinds", default: [:])
    static let liveErrorsEnabled = Key<Bool>("EnableLiveErrors", default: true)
    
    static let wordCompletionSuggestionsEnabled = Key<Bool>("EnableWordCompletionSuggestions", default: false)
    
    static let addHashbangOnSave = Key<Bool>("AddHashbangOnSave", default: true)
    static let addHashbangOnSaveProgram = Key<String>("AddHashbangOnSaveProgram", default: "/usr/local/bin/bushelscript")
    static let addHashbangOnSaveUseLanguageFlag = Key<Bool>("AddHashbangOnSaveUseLanguageFlag", default: true)
    
    static let privacyFetchAppDataForSmartSuggestions = Key<Bool>("PrivacyFetchAppDataForSmartSuggestions", default: true)
    
}
