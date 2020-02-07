import Cocoa

class RadioChoicesVC: NSViewController {
    
    @IBOutlet var choicesStackView: NSStackView!
    @IBOutlet var radioButtonTemplate: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    func addChoice(named choiceName: String) {
        // NSCell supports NSCopying
        let radioButton = NSButton(frame: .zero)
        radioButton.cell = radioButtonTemplate.cell!.copy() as? NSCell
        
        radioButton.title = choiceName
        
        choicesStackView.addArrangedSubview(radioButton)
    }
    
    var currentChoiceName: String?
    
    @IBAction func setChoice(_ sender: AnyObject) {
        currentChoiceName = sender.title
    }
    
}
