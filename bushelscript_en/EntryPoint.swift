import Foundation
import Bushel

@objc(BushelScriptEnEntryPoint)
public final class BushelScriptEnEntryPoint: NSObject, LanguageModuleEntryPoint {
    
    @objc public static let messageFormatterType: Any = EnglishMessageFormatter.self
    @objc public static let sourceParserType: Any = EnglishParser.self
    @objc public static let sourceFormatterType: Any = EnglishFormatter.self
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
}
