//
//  DocumentViewController.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 25-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa
import Bushel
import BushelRT
import BushelLanguageServiceConnectionCreation
import BushelLanguage // For errors and fixes; TODO: Move to separate "BushelADay" framework
import Defaults

private var documentFont = NSFont(name: "SF Mono", size: 13) ?? NSFont.systemFont(ofSize: 13)

class DocumentViewController: NSViewController {
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    private lazy var connection: NSXPCConnection? = self.newLanguageServiceConnection()
    private var connectionInUse: Bool = false
    
    enum Status {
        
        case compiling
        case prettyPrinting
        case running
        case fetchingData
        
        var localizedDescription: String {
            switch self {
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
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "The Bushel Language Service has crashed."
                alert.informativeText = "It will be restarted automatically. If this recurs, please file a bug report with the BushelLanguageService crash log attached.\n\nSorry for the inconvenience."
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
    
    @objc dynamic var attributedSourceCode = NSAttributedString(string: "", attributes: [.font: documentFont]) {
        didSet {
            document.undoManager?.registerUndo(withTarget: self) {
                $0.attributedSourceCode = oldValue
            }
            document.sourceCode = attributedSourceCode.string
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
            attributedSourceCode = NSAttributedString(string: document.sourceCode, attributes: [.font: documentFont])
            
            DispatchQueue.main.async {
                self.documentLanguageIDObservation = self.document.observe(\.languageID, options: [.initial]) { [weak self] (document, change) in
                    guard let self = self else { return }
                    if let wc = self.view.window?.windowController as? DocumentWindowController {
                        wc.updateLanguageMenu()
                    }
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
    
    private var program: ProgramToken? = nil
    
    private var resultInspectorPanelWC: ObjectInspectorPanelWC?
    
    @IBAction func runScript(_ sender: Any?) {
        func compileCallback(service: BushelLanguageServiceProtocol, language: LanguageModuleToken, result: Result<ProgramToken, ErrorToken>) {
            switch result {
            case .success(let program):
                status = .running
                
                service.runProgram(program, currentApplicationID: Bundle(for: DocumentViewController.self).bundleIdentifier!) { result in
                    service.releaseProgram(program, reply: { _ in })
                    self.status = nil
                    
                    DispatchQueue.main.async {
                        self.resultInspectorPanelWC?.window?.orderOut(nil)
                        
                        let resultWC = self.resultInspectorPanelWC ?? ObjectInspectorPanelWC.instantiate(for: NoSelection())
                        resultWC.window?.title = "Result"
                        resultWC.contentViewController?.representedObject = BushelRTObject(service: service, object: result as RTObjectToken)
                        
                        DispatchQueue.main.async {
                            resultWC.window?.orderFront(nil)
                            self.resultInspectorPanelWC = resultWC
                            
                        }
                        
                        
                    }
                }
            case .failure(let error):
                service.copyNSError(fromError: error) { error in
                    self.connectionInUse = false
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
                self.status = nil
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
            self.status = .prettyPrinting
            
            switch result {
            case .failure(_):
                break
            case .success(let program):
                self.program = program
                service.prettyPrintProgram(program) { pretty in
                    guard let pretty = pretty else {
                        return
                    }
                    DispatchQueue.main.sync {
                        self.document.undoManager?.setActionName("Pretty Print")
                        self.attributedSourceCode = NSAttributedString(string: pretty, attributes: [.font: documentFont])
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
                self.status = nil
                return
            }
            
            if let error = error {
                then(service, language, .failure(error))
            } else if let program = program {
                then(service, language, .success(program))
            }
        }
    }
    
    private func parse(_ source: String, then: @escaping (_ service: BushelLanguageServiceProtocol?, _ language: LanguageModuleToken?, _ program: ProgramToken?, _ error: ErrorToken?) -> Void) {
        guard let document = document else {
            // We don't know what language module to use
            return
        }
        
        status = .compiling
        guard let service = connection?.remoteObjectProxy as? BushelLanguageServiceProtocol else {
            return then(nil, nil, nil, nil)
        }
        service.loadLanguageModule(withIdentifier: document.languageID) { language in
            guard let language = language else {
                return then(service, nil, nil, nil)
            }
            service.parseSource(source, usingLanguageModule: language) { (program, error) in
                then(service, language as LanguageModuleToken, program as ProgramToken?, error as ErrorToken?)
            }
        }
    }
    
    private var suggestionListWC = SuggestionListWC.instantiate()
    private var prevSelection: NSRange?
    
}

// MARK: NSTextViewDelegate
extension DocumentViewController: NSTextViewDelegate {
    
    func textViewDidChangeSelection(_ notification: Notification) {
        let ranges = textView.selectedRanges
        guard !ranges.isEmpty else {
            dismissSuggestionList()
            return
        }
        
        let nsrange = ranges[0].rangeValue
        guard nsrange.length == 0 else {
            dismissSuggestionList()
            return
        }
        
        guard nsrange != prevSelection else {
            dismissSuggestionList()
            return
        }
        prevSelection = nsrange
        
        let text = textView.string
        guard let range = Range<String.Index>(nsrange, in: text) else {
            dismissSuggestionList()
            return
        }
        
        let sourceBeforeCaret = text[..<range.lowerBound]
        guard !sourceBeforeCaret.isEmpty else {
            return
        }
        print(sourceBeforeCaret)
        
        status = .compiling
        compile(String(sourceBeforeCaret)) { (service, language, result) in
            switch result {
            case .success(let program):
                DispatchQueue.main.sync {
                    // No errors
                    self.dismissSuggestionList()
                    
                    service.releaseProgram(program, reply: { _ in })
                    self.status = nil
                }
            case .failure(let error):
                self.status = .fetchingData
                
                service.copyNSError(fromError: error) { nsError in
                    service.getSourceFixes(fromError: error) { fixes in
                        self.status = nil
                        
                        guard !fixes.isEmpty else {
                            DispatchQueue.main.sync {
                                self.showSuggestionList(with: [ErrorSuggestionListItem(error: nsError)])
                            }
                            return
                        }
                        
                        let suggestions =
                            [ErrorSuggestionListItem(error: nsError)] +
                            fixes.map { AutoFixSuggestionListItem(service: service, fix: $0 as SourceFixToken, source: sourceBeforeCaret) } as [SuggestionListItem]
                        DispatchQueue.main.sync {
                            self.showSuggestionList(with: suggestions)
                        }
                    }
                }
            }
        }
    }
    
    func textDidEndEditing(_ notification: Notification) {
        dismissSuggestionList()
    }
    
}

// MARK: Suggestion list
extension DocumentViewController {
    
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
            DispatchQueue.main.sync {
                self.attributedSourceCode = NSAttributedString(string: fixedSource ?? self.document.sourceCode, attributes: [.font: documentFont])
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
