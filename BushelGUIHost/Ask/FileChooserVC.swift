import Cocoa

final class FileChooserVC: NSViewController {

    @IBOutlet private weak var pathTextField: NSTextField?
    
    override func viewDidLoad() {
        pathTextField?.placeholderString = (defaultLocation.path as NSString).abbreviatingWithTildeInPath
    }
    
    private(set) var defaultLocation: URL = FileManager.default.homeDirectoryForCurrentUser
    
    init(defaultLocation: URL? = nil) {
        super.init(nibName: nil, bundle: nil)
        if let defaultLocation = defaultLocation {
            self.defaultLocation = defaultLocation
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    var location: URL {
        path.isEmpty ? defaultLocation : URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
    
    @objc private dynamic var path: String = ""
    
    @IBAction func chooseFile(_ sender: Any?) {
        guard let window = view.window else {
            return
        }
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        if !path.isEmpty {
            openPanel.directoryURL = URL(fileURLWithPath: path)
        }
        
        openPanel.beginSheetModal(for: window) { [weak self] response in
            if
                let self = self,
                response == .OK,
                let selectedURL = openPanel.url
            {
                self.path = (selectedURL.path as NSString).abbreviatingWithTildeInPath
            }
        }
    }
    
}
