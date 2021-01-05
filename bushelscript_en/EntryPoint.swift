import Foundation
import BushelLanguage

@objc(BushelScriptEnEntryPoint)
public class BushelScriptEnEntryPoint: NSObject, LanguageModuleEntryPoint {
    
    @objc public static var moduleTypes: [String : Any] {
        return [
            "SourceParser": EnglishParser.self,
            "SourceFormatter": EnglishFormatter.self,
            "MessageFormatter": EnglishMessageFormatter.self
        ]
    }
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
}
