import Foundation
import BushelLanguage

@objc(BushelScriptEnglishEntryPoint)
public class BushelScriptEnglishEntryPoint: NSObject, LanguageModuleEntryPoint {
    
    @objc public static var moduleTypes: [String : Any] {
        return [
            "SourceParser": EnglishParser.self,
            "SourceFormatter": EnglishFormatter.self
        ]
    }
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
}
