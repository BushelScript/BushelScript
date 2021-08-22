import Cocoa

final class TextFieldVC: NSViewController, NSTextFieldDelegate {
    
    init() {
        super.init(nibName: nil, bundle: Bundle(for: Self.self))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBOutlet weak var textFieldFormatter: CharacterLimitFormatter?
    
    @IBOutlet weak var textField: NSTextField!
    
    var characterLimit: Int? {
        didSet {
            textFieldFormatter?.characterLimit = characterLimit
        }
    }
    
    override func viewDidLoad() {
        textFieldFormatter?.characterLimit = characterLimit
    }
    
    private(set) var value: String = ""
    
    private func updateValue(from control: NSControl) -> Bool {
        guard let string = control.objectValue as? String else {
            return false
        }
        value = string
        control.invalidDataMarker?.hide()
        return true
    }
    
    @IBAction func textFieldValueChanged(_ sender: NSControl!) {
         _ = updateValue(from: sender)
    }
    
    func control(_ control: NSControl, didFailToValidatePartialString string: String, errorDescription error: String?) {
        control.invalidDataMarker?.errorString = error ?? ""
        control.invalidDataMarker?.show()
    }
    
    func control(_ control: NSControl, didFailToFormatString string: String, errorDescription error: String?) -> Bool {
        control.invalidDataMarker?.errorString = error ?? ""
        control.invalidDataMarker?.show()
        return false
    }
    
    override func commitEditing() -> Bool {
        updateValue(from: textField)
    }
    
}

final class CharacterLimitFormatter: Formatter {
    
    var characterLimit: Int?
    
    override func isPartialStringValid(_ partialString: String, newEditingString newString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        guard let characterLimit = characterLimit else {
            return true
        }
        if partialString.count > characterLimit {
            error?.pointee = "Only \(characterLimit) character\(characterLimit == 1 ? " is" : "s are") allowed." as NSString
            return false
        }
        return true
    }
    
    override func string(for obj: Any?) -> String? {
        guard var string = obj as? String else {
            return nil
        }
        if let characterLimit = characterLimit {
            string = String(string.prefix(characterLimit))
        }
        return string
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        obj?.pointee = string as AnyObject
        return true
    }
    
}
