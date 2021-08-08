// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Bushel
import BushelRT
import Defaults

class DocumentVC: NSViewController, NSUserInterfaceValidations, SourceEditor.Delegate {
    
    @IBOutlet var sourceEditor: SourceEditor?
    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    enum Status {
        
        case running
        
        var localizedDescription: String {
            switch self {
            case .running:
                return "Running…"
            }
        }
        
    }
    
    @objc dynamic var statusText: String = ""
    
    private var isWorking: Bool = false {
        didSet {
            if self.isWorking {
                self.progressIndicator.startAnimation(self)
            } else {
                self.progressIndicator.stopAnimation(self)
            }
        }
    }
    
    var statusStack: [Status] = [] {
        didSet {
            DispatchQueue.main.async {
                let status = self.statusStack.last
                self.document?.isRunning = (status == .running)
                self.statusText = status?.localizedDescription ?? ""
                self.isWorking = (status != nil)
            }
        }
    }
    
    var sourceCode: String? {
        get {
            document?.sourceCode
        }
        set {
            guard let newValue = newValue, newValue != sourceCode else {
                return
            }
            document?.sourceCode = newValue
        }
    }
    
    var program: Program? {
        get {
            document?.program
        }
        set {
            document?.program = newValue
        }
    }
    
    var rt: Runtime? {
        get {
            document?.rt
        }
        set {
            if let newValue = newValue {
                document?.rt = newValue
            }
        }
    }
    
    var languageID: String? {
        document?.languageID
    }
    
    var documentURL: URL? {
        document?.fileURL
    }
    
    var indentMode: IndentMode? {
        document?.indentMode
    }
    
    @IBAction func increaseFontSize(_ sender: Any?) {
        customFontSize = (customFontSize ?? Defaults[.sourceCodeFont].pointSize) * 1.2
    }
    @IBAction func decreaseFontSize(_ sender: Any?) {
        customFontSize = max(1.0, (customFontSize ?? Defaults[.sourceCodeFont].pointSize) / 1.2)
    }
    @IBAction func resetFontSize(_ sender: Any?) {
        customFontSize = nil
    }
    
    private var customFontSize: CGFloat? {
        didSet {
            updateHighlightStyles()
        }
    }
    
    var defaultFont: NSFont {
        if let customFontSize = customFontSize {
            return NSFontManager.shared.convert(
                Defaults[.sourceCodeFont],
                toSize: customFontSize
            )
        } else {
            return Defaults[.sourceCodeFont]
        }
    }
    
    var highlightStyles: Styles = defaultSizeHighlightStyles ?? Styles()
    
    private func updateHighlightStyles() {
        highlightStyles = (try? makeHighlightStyles(fontSize: customFontSize)) ?? Styles()
        sourceEditor?.reload()
    }
    
    var useLiveParsing: Bool {
        Defaults[.liveParsingEnabled]
    }
    
    var useLiveErrors: Bool {
        Defaults[.liveErrorsEnabled]
    }
    
    var useWordCompletionSuggestions: Bool {
        Defaults[.wordCompletionSuggestionsEnabled]
    }
    
    override func viewDidLoad() {
        Defaults.observe(.sourceCodeFont) { [weak self] _ in
            self?.updateHighlightStyles()
        }.tieToLifetime(of: self)
        Defaults.observe(.themeFileName) { [weak self] _ in
            self?.updateHighlightStyles()
        }.tieToLifetime(of: self)
        tie(to: self, [
            NotificationObservation(.sourceEditorSelectedExpressions, sourceEditor) { [weak self] (sourceEditor, userInfo) in
                guard let document = self?.document else {
                    return
                }
                document.selectedExpressions = userInfo[.payload] as? [Expression] ?? []
                NotificationCenter.default.post(name: .documentSelectedExpressions, object: document, userInfo: userInfo)
            },
            NotificationObservation(.sourceEditorResult, sourceEditor) { [weak self] (sourceEditor, userInfo) in
                guard let document = self?.document else {
                    return
                }
                NotificationCenter.default.post(name: .documentResult, object: document, userInfo: userInfo)
            }
        ])
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        switch segue.destinationController {
        case let sourceEditor as SourceEditor:
            self.sourceEditor = sourceEditor
            sourceEditor.delegate = self
        default:
            super.prepare(for: segue, sender: sender)
        }
    }
    
    override var representedObject: Any? {
        didSet {
            if let document = representedObject as? Document {
                self.document = document
            }
        }
    }
    
    private var documentLanguageIDObservation: Any?
    
    @objc private var document: Document? {
        didSet {
            undoManager?.withoutRegistration {
                sourceEditor?.reload()
            }
            
            DispatchQueue.main.async {
                self.documentLanguageIDObservation = self.document?.observe(\.languageID, options: [.initial]) { [weak self] (document, change) in
                    guard let self = self else {
                        return
                    }
                    if let wc = self.view.window?.windowController as? DocumentWC {
                        wc.updateLanguageMenu()
                    }
                    DispatchQueue.main.async {
                        self.sourceEditor?.reload()
                    }
                }
            }
        }
    }
    
    @IBAction func setLanguage(_ sender: Any?) {
        guard
            let sender = sender,
            let maybeModuleDescriptor = (sender as AnyObject).representedObject as? LanguageModule.Descriptor?,
            let moduleDescriptor = maybeModuleDescriptor
        else {
            return
        }
        document?.languageID = moduleDescriptor.identifier
        sourceEditor?.reload()
    }
    
    @IBAction func setIndentType(_ sender: Any?) {
        guard
            let tag = (sender as AnyObject).tag,
            let character = IndentMode.Character(rawValue: tag)
        else {
            return
        }
        document?.indentMode.character = character
        sourceEditor?.reload()
    }
    @IBAction func setIndentWidth(_ sender: Any?) {
        guard let tag = (sender as AnyObject).tag else {
            return
        }
        document?.indentMode.width = tag
        sourceEditor?.reload()
    }
    
    @objc func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(runScript(_:)):
            return !(document?.isRunning ?? true)
        case #selector(terminateScript(_:)):
            return document?.isRunning ?? false
        default:
            return true
        }
    }
    
    @IBAction func reloadResources(_ sender: Any?) {
        Bushel.globalCache.clearCache()
        sourceEditor?.reload()
    }
    
    @IBAction func runScript(_ sender: Any?) {
        guard
            let sourceCode = sourceCode,
            let sourceEditor = sourceEditor
        else {
            return
        }
        
        let program: Program
        do {
            program = try Defaults[.prettyPrintBeforeRunning] ?
                sourceEditor.prettyPrint(sourceCode) :
                sourceEditor.parse(sourceCode)
        } catch {
            sourceEditor.displayError(error)
            return
        }
        
        statusStack.append(.running)
        defer {
            statusStack.removeLast()
        }
        sourceEditor.run(program)
    }
    
    @IBAction func terminateScript(_ sender: Any?) {
        document?.rt.shouldTerminate = true
    }
    
    @IBAction func prettyPrint( _ sender: Any?) {
        guard
            let sourceCode = sourceCode,
            let sourceEditor = sourceEditor
        else {
            return
        }
        
        let originalSourceCode = sourceCode
        defer {
            undoManager?.setActionName("Pretty Print")
            undoManager?.registerUndo(withTarget: self) {
                $0.sourceCode = originalSourceCode
            }
        }
        
        do {
            _ = try sourceEditor.prettyPrint(sourceCode)
        } catch {
            sourceEditor.displayError(error)
        }
    }
    
}
