import Bushel
import BushelRT

private typealias Constructor = () -> RT_Object

public func ask(_ rt: Runtime, for type: Reflection.`Type`, prompt: String, title: String, suspension: NSAppleEventManager.SuspensionID) {
    func makeViewController() -> (NSViewController, Constructor) {
        func uneditableVC() -> (UneditableVC, Constructor) {
            (UneditableVC(), { rt.null })
        }
        func fileChooserVC(defaultLocation: URL? = nil, constructor: @escaping (FileChooserVC) -> RT_Object) -> (FileChooserVC, Constructor) {
            let vc = FileChooserVC(defaultLocation: defaultLocation)
            return (vc, { constructor(vc) })
        }
        func radioChoicesVC(choices: [String], constructor: @escaping (RadioChoicesVC) -> RT_Object) -> (RadioChoicesVC, Constructor) {
            let vc = RadioChoicesVC()
            for choice in choices {
                vc.addChoice(named: choice)
            }
            return (vc, { constructor(vc) })
        }
        func checkboxVC(constructor: @escaping (CheckboxVC) -> RT_Object) -> (CheckboxVC, Constructor) {
            let vc = CheckboxVC()
            return (vc, { constructor(vc) })
        }
        func textFieldVC(characterLimit: Int? = nil, constructor: @escaping (TextFieldVC) -> RT_Object) -> (TextFieldVC, Constructor) {
            let vc = TextFieldVC()
            vc.characterLimit = characterLimit
            return (vc, { constructor(vc) })
        }
        func numberFieldVC(integersOnly: Bool = false, constructor: @escaping (NumberFieldVC) -> RT_Object) -> (NumberFieldVC, Constructor) {
            let vc = NumberFieldVC()
            vc.integersOnly = integersOnly
            return (vc, { constructor(vc) })
        }
        
        switch Types(type.uri) {
        case .boolean:
            return checkboxVC { RT_Boolean.withValue(rt, $0.value) }
        case .string:
            return textFieldVC { RT_String(rt, value: $0.value) }
        case .character:
            return textFieldVC(characterLimit: 1) { $0.value.first.map { RT_Character(rt, value: $0) } ?? rt.null }
        case .number:
            return numberFieldVC() { RT_Real(rt, value: $0.value.doubleValue) }
        case .integer:
            return numberFieldVC(integersOnly: true) { RT_Integer(rt, value: $0.value.int64Value) }
        case .real:
            return numberFieldVC() { RT_Real(rt, value: $0.value.doubleValue) }
        case .file, .alias:
            return fileChooserVC() { RT_File(rt, value: $0.location) }
        default:
            // TODO: Implement for custom types
            return uneditableVC()
        }
    }
    
    let vc = makeViewController()
    let wc = AskWC(windowNibName: "AskWC")
    
    wc.loadWindow()
    wc.embed(viewController: vc.0)
    wc.prompt = prompt
    
    let window = wc.window!
    window.title = title
    
    display(window: window) {
        returnResultToSender(vc.1(), for: suspension)
    }
}
