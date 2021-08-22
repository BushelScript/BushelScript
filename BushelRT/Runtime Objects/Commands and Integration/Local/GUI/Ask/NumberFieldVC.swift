import Cocoa

final class NumberFieldVC: NSViewController, NSTextFieldDelegate {
    
    init() {
        super.init(nibName: nil, bundle: Bundle(for: Self.self))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBOutlet weak var textFieldFormatter: NumberFormatter? {
        didSet {
            textFieldFormatter?.isPartialStringValidationEnabled = true
        }
    }
    
    @IBOutlet weak var numberField: NSTextField!
    
    var integersOnly: Bool = false {
        didSet {
            textFieldFormatter?.allowsFloats = !integersOnly
            textFieldFormatter?.isPartialStringValidationEnabled = true
        }
    }
    
    override func viewDidLoad() {
        textFieldFormatter?.allowsFloats = !integersOnly
        textFieldFormatter?.isPartialStringValidationEnabled = true
    }
    
    private(set) var value: NSNumber = 0
    
    private func updateValue(from control: NSControl) -> Bool {
        guard let number = control.objectValue as? NSNumber else {
            return false
        }
        value = number
        control.invalidDataMarker?.hide()
        return true
    }
    
    @IBAction func numberFieldValueChanged(_ sender: NSControl!) {
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
        updateValue(from: numberField)
    }
    
}
