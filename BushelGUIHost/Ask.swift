import Bushel

private typealias Constructor = () -> RT_Object

public func ask(_ rt: RTInfo, for type: TypeInfo, prompt: String) -> RT_Object {
    
    func makeViewController() -> (NSViewController, Constructor) {
        let bundle = Bundle(identifier: "com.justcheesy.BushelRT")
        
        func checkboxVC(constructor: @escaping (CheckboxVC) -> RT_Object) -> (CheckboxVC, Constructor) {
            let vc = CheckboxVC()
            return (vc, { constructor(vc) })
        }
        func radioChoicesVC(choices: [String], constructor: @escaping (RadioChoicesVC) -> RT_Object) -> (RadioChoicesVC, Constructor) {
            let vc = RadioChoicesVC()
            for choice in choices {
                vc.addChoice(named: choice)
            }
            return (vc, { constructor(vc) })
        }
        
        switch TypeUID(type.uid) {
        case .item:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .list:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .record:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .constant:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .boolean:
            return checkboxVC { vc in RT_Boolean.withValue(vc.value) }
        case .string:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .character:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .number:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .integer:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .real:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .date:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .window:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .document:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .file:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .alias:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .application:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .specifier:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .comparisonTestSpecifier:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .logicalTestSpecifier:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .`class`:
            return (NSViewController(nibName: "", bundle: bundle), { RT_Null.null })
        case .null:
            return radioChoicesVC(choices: ["Null"]) { _ in RT_Null.null }
        case .global:
            return radioChoicesVC(choices: ["Global object"]) { _ in RT_Global(rt) }
        case .script:
            return radioChoicesVC(choices: ["Script"]) { _ in rt.topScript }
        case nil:
            // TODO: Implement for custom types
            fatalError("unimplemented")
        }
    }
    
    return DispatchQueue.main.sync {
        let vc = makeViewController()
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.accessoryView = vc.0.view
        alert.runModal()
        return vc.1()
    }
    
}
