import Foundation
import BushelLanguage

@objc(BushelScriptLinearEnEntryPoint)
public class BushelScriptLinearEnEntryPoint: NSObject, LanguageModuleEntryPoint {
    
    @objc public static var moduleTypes: [String : Any] {
        return [
            "SourceParser": LinearEnglishParser.self,
            "SourceFormatter": LinearEnglishFormatter.self,
            "MessageFormatter": LinearEnglishMessageFormatter.self
        ]
    }
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
}
