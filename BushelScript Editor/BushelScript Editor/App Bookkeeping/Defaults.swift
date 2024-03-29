// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import Foundation
import Defaults

extension Defaults.Keys {
    
    static let cltInstallPath = Key<String>("CLTInstallPath", default: "/usr/local/bin/bushelscript")
    
    static let sourceCodeFont = NSSecureCodingKey<NSFont>("SourceCodeFont", default: NSFont(name: "Menlo", size: 12) ?? NSFont.systemFont(ofSize: -1))
    static let themeFileName = Key<String>("ThemeName", default: "Sunburst.tmTheme")
    static let prettyPrintBeforeRunning = Key<Bool>("PrettyPrintBeforeRunning", default: false)
    
    static let liveParsingEnabled = Key<Bool>("EnableLiveParsing", default: true)
    static let smartSuggestionsEnabled = Key<Bool>("EnableSmartSuggestions", default: true)
    static let smartSuggestionKinds = Key<[String : Bool]>("SmartSuggestionKinds", default: [:])
    static let liveErrorsEnabled = Key<Bool>("EnableLiveErrors", default: true)
    
    static let wordCompletionSuggestionsEnabled = Key<Bool>("EnableWordCompletionSuggestions", default: false)
    
    static let addHashbangOnSave = Key<Bool>("AddHashbangOnSave", default: true)
    static let addHashbangOnSaveProgram = Key<String>("AddHashbangOnSaveProgram", default: "/usr/local/bin/bushelscript")
    static let addHashbangOnSaveUseLanguageFlag = Key<Bool>("AddHashbangOnSaveUseLanguageFlag", default: true)
    
    static let privacyFetchAppForSmartSuggestions = Key<Bool>("PrivacyFetchAppForSmartSuggestions", default: true)
    
}
