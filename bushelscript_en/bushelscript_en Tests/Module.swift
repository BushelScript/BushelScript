import Bushel

@objc class Dummy: NSObject {}

let moduleID = "bushelscript_en"
let module: LanguageModule = {
    LanguageModule.appBundle = Bundle(for: Dummy.self)
    return try! LanguageModule(identifier: moduleID)
}()
