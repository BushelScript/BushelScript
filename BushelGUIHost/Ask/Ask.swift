import Bushel
import BushelRT

private typealias Constructor = () -> RT_Object

public func ask(_ rt: Runtime, for type: TypeInfo, prompt: String, title: String, suspension: NSAppleEventManager.SuspensionID) {
    
    func makeViewController() -> (NSViewController, Constructor) {
        func uneditableVC() -> (UneditableVC, Constructor) {
            (UneditableVC(), { RT_Null.null })
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
        
        switch TypeUID(type.uid) {
        case .item:
            return uneditableVC()
        case .list:
            return uneditableVC()
        case .record:
            return uneditableVC()
        case .constant:
            return uneditableVC()
        case .boolean:
            return checkboxVC { RT_Boolean.withValue($0.value) }
        case .string:
            return textFieldVC { RT_String(value: $0.value) }
        case .character:
            return textFieldVC(characterLimit: 1) { $0.value.first.map { RT_Character(value: $0) } ?? RT_Null.null }
        case .number:
            return numberFieldVC() { RT_Real(value: $0.value.doubleValue) }
        case .integer:
            return numberFieldVC(integersOnly: true) { RT_Integer(value: $0.value.int64Value) }
        case .real:
            return numberFieldVC() { RT_Real(value: $0.value.doubleValue) }
        case .date:
            return uneditableVC()
        case .window:
            return uneditableVC()
        case .document:
            return uneditableVC()
        case .file, .alias:
            return fileChooserVC() { RT_File(value: $0.location) }
        case .application:
            return uneditableVC()
        case .specifier:
            return uneditableVC()
        case .comparisonTestSpecifier:
            return uneditableVC()
        case .logicalTestSpecifier:
            return uneditableVC()
        case .`class`:
            return uneditableVC()
        case .null:
            return uneditableVC()
        case .global:
            return uneditableVC()
        case .script:
            return uneditableVC()
        case .function:
            return uneditableVC()
        case .system:
            return uneditableVC()
        case nil:
            // TODO: Implement for custom types
            fatalError("unimplemented")
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
