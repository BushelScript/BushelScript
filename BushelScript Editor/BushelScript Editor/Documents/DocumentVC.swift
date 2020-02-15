//
//  DocumentVC.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 25-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa
import Bushel
import BushelLanguage // For module descriptors
import BushelLanguageServiceConnectionCreation
import Defaults

class DocumentVC: NSViewController {
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    @objc dynamic var resultInspectorPanelWC: ObjectInspectorPanelWC?
    
    private lazy var connection: NSXPCConnection? = self.newLanguageServiceConnection()
    private var connectionInUse: Bool = false
    
    enum Status {
        
        case loadingLanguageModule
        case compiling
        case prettyPrinting
        case running
        case fetchingData
        
        var localizedDescription: String {
            switch self {
            case .loadingLanguageModule:
                return "Loading language module…"
            case .compiling:
                return "Compiling…"
            case .prettyPrinting:
                return "Pretty printing…"
            case .running:
                return "Running…"
            case .fetchingData:
                return "Fetching data…"
            }
        }
        
    }
    
    var status: Status? {
        didSet {
            DispatchQueue.main.async {
                self.document.isRunning = (self.status == .running)
                
                self.connectionInUse = (self.status != nil)
                self.isWorking = self.connectionInUse
                self.statusText = self.status?.localizedDescription ?? ""
            }
        }
    }
    private var isWorking: Bool = false {
        didSet {
            if self.isWorking {
                self.progressIndicator.startAnimation(self)
            } else {
                self.progressIndicator.stopAnimation(self)
            }
        }
    }
    @objc dynamic var statusText: String = ""
    
    private func newLanguageServiceConnection() -> NSXPCConnection {
        return NSXPCConnection.bushelLanguageServiceConnection(interruptionHandler: { [weak self] in
            guard
                let self = self,
                self.connectionInUse
            else {
                return
            }
            self.connection = nil
            self.status = nil
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "The Bushel Language Service has crashed."
                alert.informativeText = "It will be restarted automatically.\n\nIf your script exited due to an error, you can ignore this message. Proper error handling will be introduced in a future update.\n\nOtherwise, if this recurs, please file a bug report with the BushelLanguageService crash log attached.\n\nSorry for the inconvenience."
                alert.runModal()
                self.connection = self.newLanguageServiceConnection()
            }
        }, invalidationHandler: { [weak self] in
            guard
                let self = self,
                self.connectionInUse
            else {
                return
            }
            self.connection = nil
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Couldn't connect to the Bushel Language Service."
                alert.informativeText = "There is a problem with your BushelScript installation. Please reinstall BushelScript and try again.\n\nBushelScript Editor will now be quit."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Quit")
                alert.runModal()
                NSApplication.shared.terminate(self)
            }
        })
    }
    
    private var documentFont: NSFont {
        Defaults[.sourceCodeFont]
    }
    
    @objc dynamic var sourceCode = "" {
        didSet {
            document.undoManager?.registerUndo(withTarget: self) {
                $0.sourceCode = oldValue
            }
            document.sourceCode = sourceCode
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        if let window = view.window {
            NotificationCenter.default.addObserver(self, selector: #selector(repositionSuggestionWindow), name: NSWindow.didMoveNotification, object: window)
        }
    }
    
    override func viewWillDisappear() {
        dismissSuggestionList()
        resultInspectorPanelWC?.close()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
            if let document = representedObject as? Document {
                self.document = document
            }
        }
    }
    
    private var documentLanguageIDObservation: Any?
    
    private var document: Document! {
        didSet {
            document.undoManager?.disableUndoRegistration()
            defer { document.undoManager?.enableUndoRegistration() }
            sourceCode = document.sourceCode
            
            DispatchQueue.main.async {
                self.documentLanguageIDObservation = self.document.observe(\.languageID, options: [.initial]) { [weak self] (document, change) in
                    guard let self = self else { return }
                    if let wc = self.view.window?.windowController as? DocumentWC {
                        wc.updateLanguageMenu()
                    }
                    self.compile(document.sourceCode, then: { _, _, _ in })
                }
            }
            
        }
    }
    
    @IBAction func setLanguage(_ sender: Any?) {
        guard
            let sender = sender,
            let maybeModuleDescriptor = (sender as AnyObject).representedObject as? LanguageModule.ModuleDescriptor?,
            let moduleDescriptor = maybeModuleDescriptor
        else {
            return
        }
        document.languageID = moduleDescriptor.identifier
        program = nil
    }
    
    @IBAction func runScript(_ sender: Any?) {
        func compileCallback(service: BushelLanguageServiceProtocol, language: LanguageModuleToken, result: Result<ProgramToken, ErrorToken>) {
            switch result {
            case .success(let program):
                status = .running
                service.runProgram(program, scriptName: document.displayName, currentApplicationID: Bundle(for: DocumentVC.self).bundleIdentifier!) { result in
                    self.status = nil
                    
                    DispatchQueue.main.async {
                        self.resultInspectorPanelWC?.window?.orderOut(nil)
                        
                        let resultWC = self.resultInspectorPanelWC ?? ObjectInspectorPanelWC.instantiate(for: NoSelection())
                        resultWC.window?.title = "Result\(self.document.displayName.map { " – \($0)" } ?? "")"
                        resultWC.contentViewController?.representedObject = BushelRTObject(service: service, object: result as RTObjectToken)
                        
                        DispatchQueue.main.async {
                            resultWC.window?.orderFront(nil)
                            self.resultInspectorPanelWC = resultWC
                            
                        }
                        
                        
                    }
                }
            case .failure(let error):
                status = .fetchingData
                service.copyNSError(fromError: error) { error in
                    self.status = nil
                    DispatchQueue.main.async {
                        self.presentError(error)
                    }
                }
            }
        }
        
        let source = document.sourceCode
        if Defaults[.prettyPrintBeforeRunning] {
            prettyPrint(source, then: compileCallback)
        } else {
            compile(source, then: compileCallback)
        }
    }
    
    @IBAction func compileScript( _ sender: Any?) {
        prettyPrint(document.sourceCode) { service, language, result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
                self.status = .fetchingData
                service.copyNSError(fromError: error) { error in
                    self.status = nil
                    DispatchQueue.main.async {
                        self.presentError(error)
                    }
                }
            }
        }
    }
    
    private func prettyPrint(_ source: String, then: @escaping (_ service: BushelLanguageServiceProtocol, _ language: LanguageModuleToken, _ result: Result<ProgramToken, ErrorToken>) -> Void) {
        compile(source) { service, language, result in
            switch result {
            case .failure(_):
                break
            case .success(let program):
                self.status = .prettyPrinting
                // TOOD: When pretty printing is fixed, change this back to: service.prettyPrintProgram(program)
                service.reformatProgram(program, usingLanguageModule: language) { pretty in
                    self.status = nil
                    guard let pretty = pretty else {
                        return
                    }
                    DispatchQueue.main.sync {
                        self.document.undoManager?.setActionName("Pretty Print")
                        self.sourceCode = pretty
                    }
                }
            }
            then(service, language, result)
        }
    }
    
    private enum Result<Success, Failure> {
        
        case success(Success)
        case failure(Failure)
        
    }
    
    private func compile(_ source: String, then: @escaping (_ service: BushelLanguageServiceProtocol, _ language: LanguageModuleToken, _ result: Result<ProgramToken, ErrorToken>) -> Void) {
        parse(source) { service, language, program, error in
            guard
                let service = service,
                let language = language
            else {
                return
            }
            
            if let error = error {
                then(service, language, .failure(error))
            } else if let program = program {
                then(service, language, .success(program))
                DispatchQueue.main.async {
                    self.program = (program, source)
                    self.textViewDidChangeSelection()
                }
            }
        }
    }
    
    private func parse(_ source: String, then: @escaping (_ service: BushelLanguageServiceProtocol?, _ language: LanguageModuleToken?, _ program: ProgramToken?, _ error: ErrorToken?) -> Void) {
        guard let document = document else {
            // We don't know what language module to use
            return
        }
        guard let service = self.service else {
            return then(nil, nil, nil, nil)
        }
        
        status = .loadingLanguageModule
        service.loadLanguageModule(withIdentifier: document.languageID) { language in
            self.status = nil
            guard let language = language else {
                return then(service, nil, nil, nil)
            }
            
            self.status = .compiling
            service.parseSource(source, usingLanguageModule: language) { (program, error) in
                self.status = nil
                then(service, language as LanguageModuleToken, program as ProgramToken?, error as ErrorToken?)
            }
        }
    }
    
    private var service: BushelLanguageServiceProtocol? {
        connection?.remoteObjectProxy as? BushelLanguageServiceProtocol
    }
    
    private var suggestionListWC = SuggestionListWC.instantiate()
    private var program: (token: ProgramToken, source: String)? {
        didSet {
            if let (token, _) = oldValue {
                service?.releaseProgram(token, reply: { _ in })
            }
        }
    }
    
    @objc dynamic var expression: BushelExpression?
    
    @IBOutlet weak var sidebarObjectInspectorView: NSView!
    
    @IBSegueAction
    func embedSidebarObjectInspector(coder: NSCoder) -> NSViewController? {
        guard let vc = NSViewController(coder: coder) else {
            return nil
        }
        vc.bind(NSBindingName(rawValue: #keyPath(ObjectInspectorVC.representedObject)), to: self, withKeyPath: #keyPath(DocumentVC.expression), options: nil)
        DispatchQueue.main.async {
            if let superview = vc.view.superview {
                // Prevent this autogenerated view's autoresizing mask constraints
                // from clipping the embedded content.
                superview.translatesAutoresizingMaskIntoConstraints = false
                superview.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor).isActive = true
                superview.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor).isActive = true
                superview.topAnchor.constraint(equalTo: vc.view.topAnchor).isActive = true
                superview.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor).isActive = true
            }
            
            if let outerView = self.sidebarObjectInspectorView {
                // Pin the embedded view to top, leading and trailing, and force
                // the outer sizing view's height to equal that of the embedded view.
                vc.view.translatesAutoresizingMaskIntoConstraints = false
                vc.view.leadingAnchor.constraint(equalTo: outerView.leadingAnchor).isActive = true
                vc.view.trailingAnchor.constraint(equalTo: outerView.trailingAnchor).isActive = true
                vc.view.topAnchor.constraint(equalTo: outerView.topAnchor).isActive = true
                vc.view.heightAnchor.constraint(equalTo: outerView.heightAnchor).isActive = true
            }
        }
        return vc
    }
    
    private var inlineErrorVC: InlineErrorVC?
    
}

// MARK: NSTextViewDelegate
extension DocumentVC: NSTextViewDelegate {
    
    func textDidChange(_ notification: Notification) {
        let source = textView.string
        
        if program != nil {
            program = nil
        }
        
        guard Defaults[.liveParsingEnabled] else {
            return
        }
        
        compile(source) { (service, language, result) in
            switch result {
            case .success(_):
                DispatchQueue.main.sync {
                    // No errors
                    self.removeErrorDisplay()
//                    self.dismissSuggestionList()
                }
            case .failure(let error):
                guard Defaults[.liveErrorsEnabled] else {
                    return
                }
                
                self.status = .fetchingData
                service.copyNSError(fromError: error) { nsError in
                    service.copySourceCharacterRange(fromError: error, forSource: source) { errorRangeValue in
                        self.status = nil
                        if let errorRangeValue = errorRangeValue {
                            let errorNSRange = errorRangeValue.rangeValue
                            DispatchQueue.main.sync {
                                guard source == self.textView.string else {
                                    // Text has changed since this information was generated
                                    return
                                }
                                self.removeErrorDisplay()
                                self.display(error: nsError, at: errorNSRange)
                            }
                        }
                    }
//                    service.getSourceFixes(fromError: error) { fixes in
//                        self.status = nil
//
//                        guard !fixes.isEmpty else {
//                            DispatchQueue.main.sync {
//                                self.showSuggestionList(with: [ErrorSuggestionListItem(error: nsError)])
//                            }
//                            return
//                        }
//
//                        let suggestions =
//                            [ErrorSuggestionListItem(error: nsError)] +
//                            fixes.map { AutoFixSuggestionListItem(service: service, fix: $0 as SourceFixToken, source: Substring(source)) } as [SuggestionListItem]
//                        DispatchQueue.main.sync {
//                            self.showSuggestionList(with: suggestions)
//                        }
//                    }
                }
            }
        }
    }
    
    private func display(error: Error, at sourceRange: NSRange) {
        func hightlightError() {
            textView.textStorage?.addAttribute(.backgroundColor, value: NSColor(named: "ErrorHighlightColor")!, range: sourceRange)
            textView.typingAttributes[.backgroundColor] = nil
        }
        func addInlineErrorView() {
            let firstLineScreenRect = textView.firstRect(forCharacterRange: sourceRange, actualRange: nil)
            guard firstLineScreenRect != .zero else {
                // Not visible in scroll view
                return
            }
            guard let window = view.window else {
                return
            }
            // Convert from screen coordinates
            let firstLineRect = window.convertFromScreen(firstLineScreenRect)
            // Flip coordinates for text view
            let firstLineFlippedRect = firstLineRect.applying(
                CGAffineTransform(translationX: 0, y: textView.frame.height)
                    .scaledBy(x: 1, y: -1)
            )
            
            let inlineErrorVC = InlineErrorVC()
            self.inlineErrorVC = inlineErrorVC
            inlineErrorVC.representedObject = error
            
            let errorView = inlineErrorVC.view
            textView.addSubview(errorView)
            
            let fontHeightAdjust = documentFont.capHeight * 2.0
            errorView.frame.origin.y = firstLineFlippedRect.minY + errorView.frame.height + fontHeightAdjust
            errorView.leadingAnchor.constraint(greaterThanOrEqualTo: textView.leadingAnchor).isActive = true
            errorView.trailingAnchor.constraint(equalTo: textView.trailingAnchor).isActive = true
        }
        
        removeErrorDisplay()
        
        hightlightError()
        addInlineErrorView()
    }
    
    private func removeErrorDisplay() {
        func clearErrorHighlighting() {
            textView.textStorage?.setAttributes([.font: documentFont], range: NSRange(location: 0, length: (self.textView.string as NSString).length))
        }
        func removeInlineErrorView() {
            guard let oldInlineErrorVC = self.inlineErrorVC else {
                return
            }
            self.inlineErrorVC = nil
            oldInlineErrorVC.view.removeFromSuperview()
        }
        
        clearErrorHighlighting()
        removeInlineErrorView()
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
        textViewDidChangeSelection()
    }

    private func textViewDidChangeSelection() {
        let ranges = textView.selectedRanges
        guard !ranges.isEmpty else {
            return
        }

        let nsrange = ranges[0].rangeValue
        guard nsrange.length == 0 else {
            return
        }

        let text = textView.string
        guard let range = Range<String.Index>(nsrange, in: text) else {
            return
        }

        updateExpressionInspector(for: range)
    }
    
    func textDidEndEditing(_ notification: Notification) {
        dismissSuggestionList()
    }
    
}

// MARK: Suggestion list
extension DocumentVC {
    
    private func showSuggestionList(with suggestions: [SuggestionListItem]) {
        guard !suggestions.isEmpty else {
            self.dismissSuggestionList()
            return
        }
        
        let vc = self.suggestionListWC.contentViewController as! SuggestionListVC
        vc.documentVC = self
        vc.representedObject = suggestions
        
        self.repositionSuggestionWindow()
        
        self.suggestionListWC.showWindow(self)
    }
    
    func apply(suggestion: AutoFixSuggestionListItem) {
        suggestion.service.applyFix(suggestion.fix, toSource: document.sourceCode) { fixedSource in
            if let fixedSource = fixedSource {
                DispatchQueue.main.sync {
                    self.sourceCode = fixedSource
                }
            }
        }
    }
    
    @objc private func repositionSuggestionWindow() {
        guard
            let window = suggestionListWC.window,
            let selectedRange = textView.selectedRanges.first?.rangeValue
        else {
            return
        }
        
        var selectionOrigin = textView.firstRect(forCharacterRange: selectedRange, actualRange: nil).origin
        selectionOrigin.y -= window.frame.height
        window.setFrameOrigin(selectionOrigin)
        
    }
    
    private func dismissSuggestionList() {
        suggestionListWC.close()
    }
    
}

// MARK: Expression inspector
extension DocumentVC {
    
    private func updateExpressionInspector(for selectedRange: Range<String.Index>) {
        guard
            let service = service,
            let (program, source) = program,
            source.range.contains(selectedRange)
        else {
            return
        }
        
        let indexDistance = source.distance(from: source.startIndex, to: selectedRange.lowerBound)
        
        service.getExpressionAtLocation(indexDistance, inSourceOfProgram: program) { (expression) in
            guard let expression = expression else {
                return
            }
            DispatchQueue.main.async {
                self.expression = BushelExpression(service: service, expression: expression as ExpressionToken)
            }
        }
    }
    
}
