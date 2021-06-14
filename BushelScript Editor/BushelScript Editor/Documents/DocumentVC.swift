// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Bushel
import BushelLanguageServiceConnectionCreation
import Defaults

private func defaultSourceCodeAttributes() -> [NSAttributedString.Key : Any] {
    [
        .font: Defaults[.sourceCodeFont],
        .foregroundColor: NSColor.white
    ]
}

class DocumentVC: NSViewController {
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    @objc dynamic var resultInspectorPanelWC: ObjectInspectorPanelWC?
    
    private lazy var connection: NSXPCConnection? = self.newLanguageServiceConnection()
    private var connectionInUse: Bool = false
    
    enum Status {
        
        case loadingLanguageModule
        case compiling
        case highlighting
        case prettyPrinting
        case running
        case fetchingData
        
        var localizedDescription: String {
            switch self {
            case .loadingLanguageModule:
                return "Loading language module…"
            case .compiling:
                return "Compiling…"
            case .highlighting:
                return "Highlighting syntax…"
            case .prettyPrinting:
                return "Pretty printing…"
            case .running:
                return "Running…"
            case .fetchingData:
                return "Fetching data…"
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
                
                self.document.isRunning = (status == .running)
                
                self.connectionInUse = (status != nil)
                self.isWorking = self.connectionInUse
                self.statusText = status?.localizedDescription ?? ""
            }
        }
    }
    
    var status: Status? {
        statusStack.last
    }
    
    func pushStatus(_ status: Status) {
        statusStack.append(status)
    }
    
    func popStatus(_ status: Status) {
        statusStack.removeAll { $0 == status }
    }
    
    func clearStatus() {
        statusStack.removeAll()
    }
    
    private func newLanguageServiceConnection() -> NSXPCConnection {
        return NSXPCConnection.bushelLanguageServiceConnection(interruptionHandler: { [weak self] in
            guard
                let self = self,
                self.connectionInUse
            else {
                return
            }
            self.connection = nil
            self.clearStatus()
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "The Bushel Language Service has crashed."
                alert.informativeText = "It will be restarted automatically.\n\nIf this recurs, please file a bug report with the BushelLanguageService crash log attached.\n\nSorry for the inconvenience."
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
    
    var displayedAttributedSourceCode = NSAttributedString(string: "") {
        didSet {
            let selectedRanges = textView.selectedRanges
            let selectionAffinity = textView.selectionAffinity
            let selectionGranularity = textView.selectionGranularity
            defer {
                textView.setSelectedRanges(selectedRanges, affinity: selectionAffinity, stillSelecting: false)
                textView.selectionGranularity = selectionGranularity
            }
            
            let textUpdated = (displayedSourceCode != textView.string)
            
            if textUpdated {
                guard textView.shouldChangeText(in: NSRange(location: 0, length: (textView.string as NSString).length), replacementString: displayedSourceCode) else {
                    return
                }
            }
            defer {
                if textUpdated {
                    textView.didChangeText()
                }
                
                textView.typingAttributes = defaultSourceCodeAttributes()
            }
            
            textView.textStorage?.beginEditing()
            textView.textStorage?.setAttributedString(self.displayedAttributedSourceCode)
            textView.textStorage?.endEditing()
        }
    }
    
    var displayedSourceCode: String {
        get {
            displayedAttributedSourceCode.string
        }
        set {
            displayedAttributedSourceCode = NSAttributedString(string: newValue, attributes: defaultSourceCodeAttributes())
        }
    }
    
    var modelSourceCode: String {
        get {
            document.sourceCode
        }
        set {
            document.sourceCode = newValue
        }
    }
    
    private func setModelSourceCodeUndoable(_ newValue: String, actionName: String) {
        let oldValue = modelSourceCode
        
        modelSourceCode = newValue
        
        document.undoManager?.setActionName(actionName)
        document.undoManager?.registerUndo(withTarget: self) {
            $0.modelSourceCode = oldValue
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
            if let document = representedObject as? Document {
                self.document = document
            }
        }
    }
    
    private var documentLanguageIDObservation: Any?
    
    private var document: Document! {
        didSet {
            document.undoManager?.disableUndoRegistration()
            defer {
                document.undoManager?.enableUndoRegistration()
            }
            displayedSourceCode = document.sourceCode
            
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
            let maybeModuleDescriptor = (sender as AnyObject).representedObject as? LanguageModule.Descriptor?,
            let moduleDescriptor = maybeModuleDescriptor
        else {
            return
        }
        document.languageID = moduleDescriptor.identifier
        program = nil
    }
    
    @IBAction func runScript(_ sender: Any?) {
        func runCallback(service: BushelLanguageServiceProtocol, language: LanguageModuleToken, result: Result<RTObjectToken, ErrorToken>) {
            switch result {
            case .success(let result):
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
            case .failure(let errorToken):
                pushStatus(.fetchingData)
                service.copyNSError(fromError: errorToken) { error in
                    self.popStatus(.fetchingData)
//                    DispatchQueue.main.async {
//                        self.presentError(error)
                        self.displayInlineError(for: errorToken, source: self.modelSourceCode, via: service)
//                    }
                }
            }
        }
        func compileCallback(service: BushelLanguageServiceProtocol, language: LanguageModuleToken, result: Result<ProgramToken, ErrorToken>) {
            switch result {
            case .success(let program):
                run(program, service, language, then: runCallback)
            case .failure(let error):
//                pushStatus(.fetchingData)
//                service.copyNSError(fromError: error) { error in
//                    self.popStatus(.fetchingData)
//                    DispatchQueue.main.async {
//                        self.presentError(error)
//                    }
                    self.displayInlineError(for: error, source: self.modelSourceCode, via: service)
//                }
            }
        }
        
        let source = modelSourceCode
        if Defaults[.prettyPrintBeforeRunning] {
            prettyPrint(source, then: compileCallback)
        } else {
            compile(source, then: compileCallback)
        }
    }
    
    @IBAction func compileScript( _ sender: Any?) {
        prettyPrint(modelSourceCode) { service, language, result in
            switch result {
            case .success(_):
                break
            case .failure(let error):
//                self.pushStatus(.fetchingData)
//                service.copyNSError(fromError: error) { error in
//                    self.popStatus(.fetchingData)
//                    DispatchQueue.main.async {
//                        self.presentError(error)
//                    }
                self.displayInlineError(for: error, source: self.modelSourceCode, via: service)
//                }
            }
        }
    }
    
    private func run(_ program: ProgramToken, _ service: BushelLanguageServiceProtocol, _ language: LanguageModuleToken, then: @escaping (_ service: BushelLanguageServiceProtocol, _ language: LanguageModuleToken, _ result: Result<RTObjectToken, ErrorToken>) -> Void) {
        pushStatus(.running)
        service.runProgram(program, scriptName: self.document.displayName, currentApplicationID: Bundle(for: DocumentVC.self).bundleIdentifier!) { result, error in
            self.popStatus(.running)
            if let error = error as ErrorToken? {
                then(service, language, .failure(error))
            } else if let result = result as RTObjectToken? {
                then(service, language, .success(result))
            }
        }
    }
    
    private func prettyPrint(_ source: String, then: @escaping (_ service: BushelLanguageServiceProtocol, _ language: LanguageModuleToken, _ result: Result<ProgramToken, ErrorToken>) -> Void) {
        compile(source) { service, language, result in
            switch result {
            case .failure(_):
                break
            case .success(let program):
                self.pushStatus(.prettyPrinting)
                service.prettyPrintProgram(program) { pretty in
                    self.popStatus(.prettyPrinting)
                    guard let pretty = pretty else {
                        return
                    }
                    DispatchQueue.main.sync {
                        self.setModelSourceCodeUndoable(pretty, actionName: "Pretty Print")
                        self.displayedSourceCode = self.modelSourceCode
                        self.compile(self.modelSourceCode, then: { _, _, _ in })
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
        func highlightPassthroughThen(service: BushelLanguageServiceProtocol, language: LanguageModuleToken, result: Result<ProgramToken, ErrorToken>) {
            switch result {
            case .success(let program):
                self.pushStatus(.highlighting)
                service.highlightProgram(program) { prettyData in
                    self.popStatus(.highlighting)
                    guard
                        let prettyData = prettyData,
                        let pretty = try? NSAttributedString(data: prettyData, options: [.documentType: NSAttributedString.DocumentType.rtf, .defaultAttributes: defaultSourceCodeAttributes()], documentAttributes: nil)
                    else {
                        return
                    }
                    
                    let prettyCopy = pretty.mutableCopy() as! NSMutableAttributedString
                    prettyCopy.addAttribute(.font, value: self.documentFont, range: NSRange(location: 0, length: (prettyCopy.string as NSString).length))
                    
                    DispatchQueue.main.sync {
                        guard source == self.textView.string else {
                            // Text has changed since this information was generated
                            return
                        }
                        
                        self.document.undoManager?.disableUndoRegistration()
                        defer {
                            self.document.undoManager?.enableUndoRegistration()
                        }
                        self.displayedAttributedSourceCode = prettyCopy
                    }
                }
            case .failure(_):
                break
            }
            
            then(service, language, result)
        }
        
        let then = highlightPassthroughThen
        
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
        
        pushStatus(.loadingLanguageModule)
        service.loadLanguageModule(withIdentifier: document.languageID) { language in
            self.popStatus(.loadingLanguageModule)
            guard let language = language else {
                return then(service, nil, nil, nil)
            }
            
            self.pushStatus(.compiling)
            service.parseSource(source, at: document.fileURL, usingLanguageModule: language) { (program, error) in
                self.popStatus(.compiling)
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
        textDidChange()
    }
    
    private func textDidChange() {
        let source = textView.string
        modelSourceCode = source
        
        if program != nil {
            program = nil
        }
        
        guard Defaults[.liveParsingEnabled] else {
            return
        }
        
        compile(source) { (service, language, result) in
            switch result {
            case .success(_):
                DispatchQueue.main.async {
                    // No errors
                    self.removeErrorDisplay()
//                    self.dismissSuggestionList()
                }
                
            case .failure(let error):
                guard Defaults[.liveErrorsEnabled] else {
                    return
                }
                self.displayInlineError(for: error, source: source, via: service)
            }
        }
    }
    
    private func displayInlineError(for error: ErrorToken, source: String, via service: BushelLanguageServiceProtocol) {
        pushStatus(.fetchingData)
        service.copyNSError(fromError: error) { nsError in
            service.copySourceCharacterRange(fromError: error, forSource: source) { errorRangeValue in
                self.popStatus(.fetchingData)
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
//            service.getSourceFixes(fromError: error) { fixes in
//                self.popStatus(.fetchingData)
//
//                guard !fixes.isEmpty else {
//                    DispatchQueue.main.sync {
//                        self.showSuggestionList(with: [ErrorSuggestionListItem(error: nsError)])
//                    }
//                    return
//                }
//
//                let suggestions =
//                    [ErrorSuggestionListItem(error: nsError)] +
//                    fixes.map { AutoFixSuggestionListItem(service: service, fix: $0 as SourceFixToken, source: Substring(source)) } as [SuggestionListItem]
//                DispatchQueue.main.sync {
//                    self.showSuggestionList(with: suggestions)
//                }
//            }
        }
    }
    
    private func display(error: Error, at sourceRange: NSRange) {
        func hightlightError() {
            guard
                let textStorage = textView.textStorage,
                let swiftRange = Range(sourceRange, in: textStorage.string),
                textStorage.string.range.contains(swiftRange)
            else {
                return
            }
            textStorage.addAttribute(.backgroundColor, value: NSColor(named: "ErrorHighlightColor")!, range: sourceRange)
            textView.typingAttributes = defaultSourceCodeAttributes()
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
            let entireSourceRange = NSRange(location: 0, length: (self.textView.string as NSString).length)
            textView.textStorage?.removeAttribute(.backgroundColor, range: entireSourceRange)
            textView.typingAttributes = defaultSourceCodeAttributes()
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
                    self.setModelSourceCodeUndoable(fixedSource, actionName: "Apply Fix")
                    self.displayedSourceCode = self.modelSourceCode
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
