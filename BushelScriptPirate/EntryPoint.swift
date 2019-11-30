import Foundation
import BushelLanguage

@objc(BushelScriptPirateEntryPoint)
public class BushelScriptPirateEntryPoint: NSObject, LanguageModuleEntryPoint {
    
    @objc public static var moduleTypes: [String : Any] {
        return [
            "SourceParser": PirateParser.self,
            "SourceFormatter": PirateFormatter.self
        ]
    }
    
    @available(*, unavailable)
    override init() {
        fatalError()
    }
    
}
