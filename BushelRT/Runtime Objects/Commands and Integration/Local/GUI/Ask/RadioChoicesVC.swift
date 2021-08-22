import Cocoa

final class RadioChoicesVC: NSViewController {
    
    init() {
        super.init(nibName: nil, bundle: Bundle(for: Self.self))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBOutlet var choicesStackView: NSStackView!
    @IBOutlet var radioButtonTemplate: NSButton!
    
    var currentChoiceName: String?
    
    func addChoice(named choiceName: String) {
        // Load the view
        _ = self.view
        
        // NSCell supports NSCopying
        let radioButton = NSButton(frame: CGRect.zero)
        radioButton.cell = radioButtonTemplate.cell!.copy() as? NSCell
        
        radioButton.title = choiceName
        
        choicesStackView.addArrangedSubview(radioButton)
        
        if currentChoiceName == nil {
            currentChoiceName = choiceName
            radioButton.state = .on
        }
    }
    
    @IBAction func setChoice(_ sender: NSButton!) {
        currentChoiceName = sender.title
    }
    
}
