// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Bushel
import BushelRT
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
    
    private var runQueue = DispatchQueue(label: "Run program", qos: .userInitiated)
    
    private var program: Bushel.Program?
    
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
                self.statusText = status?.localizedDescription ?? ""
                self.isWorking = (status != nil)
            }
        }
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
                    DispatchQueue.main.async {
                        do {
                            _ = try self.compile(document.sourceCode)
                        } catch {
                            self.displayInlineError(error)
                        }
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
        document.languageID = moduleDescriptor.identifier
        program = nil
    }
    
    @IBAction func runScript(_ sender: Any?) {
        let program: Program
        do {
            program = try Defaults[.prettyPrintBeforeRunning] ?
                self.prettyPrint(self.modelSourceCode) :
                self.compile(self.modelSourceCode)
        } catch {
            self.displayInlineError(error)
            return
        }
        runQueue.async {
            self.statusStack.append(.running)
            defer {
                self.statusStack.removeLast()
            }
            do {
                let result = try self.document.rt.run(program)
                NotificationCenter.default.post(name: .result, object: self.document, userInfo: [UserInfo.payload: result])
            } catch {
                self.displayInlineError(error)
            }
        }
    }
    
    @IBAction func compileScript( _ sender: Any?) {
        do {
            _ = try prettyPrint(modelSourceCode)
        } catch {
            displayInlineError(error)
        }
    }
    
    private func prettyPrint(_ source: String) throws -> Program {
        let program = try compile(source)
        let pretty = Bushel.prettyPrint(program.elements)
        setModelSourceCodeUndoable(pretty, actionName: "Pretty Print")
        displayedSourceCode = modelSourceCode
        return try compile(modelSourceCode)
    }
    
    private func compile(_ source: String) throws -> Program {
        let program = try parse(source)
        
        let highlighted = NSMutableAttributedString(attributedString: highlight(source: Substring(source), program.elements, with: [
            .comment: CGColor(gray: 0.7, alpha: 1.0),
            .keyword: CGColor(red: 234 / 255.0, green: 156 / 255.0, blue: 119 / 255.0, alpha: 1.0),
            .operator: CGColor(red: 234 / 255.0, green: 156 / 255.0, blue: 119 / 255.0, alpha: 1.0),
            .dictionary: CGColor(red: 200 / 255.0, green: 229 / 255.0, blue: 100 / 255.0, alpha: 1.0),
            .type: CGColor(red: 177 / 255.0, green: 229 / 255.0, blue: 138 / 255.0, alpha: 1.0),
            .property: CGColor(red: 224 / 255.0, green: 197 / 255.0, blue: 137 / 255.0, alpha: 1.0),
            .constant: CGColor(red: 253 / 255.0, green: 143 / 255.0, blue: 63 / 255.0, alpha: 1.0),
            .command: CGColor(red: 238 / 255.0, green: 223 / 255.0, blue: 112 / 255.0, alpha: 1.0),
            .parameter: CGColor(red: 207 / 255.0, green: 106 / 255.0, blue: 76 / 255.0, alpha: 1.0),
            .variable: CGColor(red: 153 / 255.0, green: 202 / 255.0, blue: 255 / 255.0, alpha: 1.0),
            .resource: CGColor(red: 88 / 255.0, green: 176 / 255.0, blue: 188 / 255.0, alpha: 1.0),
            .number: CGColor(red: 72 / 255.0, green: 148 / 255.0, blue: 209 / 255.0, alpha: 1.0),
            .string: CGColor(red: 118 / 255.0, green: 186 / 255.0, blue: 83 / 255.0, alpha: 1.0),
            .weave: CGColor(gray: 0.9, alpha: 1.0),
        ]))
        
        highlighted.addAttribute(.font, value: self.documentFont, range: NSRange(location: 0, length: (highlighted.string as NSString).length))
        
        self.document.undoManager?.disableUndoRegistration()
        defer {
            self.document.undoManager?.enableUndoRegistration()
        }
        self.displayedAttributedSourceCode = highlighted
        
        return program
    }
    
    private func parse(_ source: String) throws -> Program {
        let program = try Bushel.parse(source: source, languageID: document.languageID, ignoringImports: document.fileURL.map { [$0] } ?? [])
        self.program = program
        return program
    }
    
    @IBOutlet weak var sidebarObjectInspectorView: NSView!
    
    private var inlineErrorVC: InlineErrorVC?
    
}

// MARK: NSTextViewDelegate
extension DocumentVC: NSTextViewDelegate {
    
    func textDidChange(_ notification: Notification) {
        textDidChange()
    }
    
    private func textDidChange() {
        removeErrorDisplay()
        
        let source = textView.string
        modelSourceCode = source
        
        if program != nil {
            program = nil
        }
        
        if Defaults[.liveParsingEnabled] {
            do {
                _ = try compile(source)
            } catch {
                if Defaults[.liveErrorsEnabled] {
                    displayInlineError(error)
                }
            }
        }
    }
    
    private func displayInlineError(_ error: Error) {
        DispatchQueue.main.async {
            guard let location = (error as? Located)?.location else {
                self.presentError(error)
                return
            }
            self.removeErrorDisplay()
            self.display(error: error, at: location.range)
        }
    }
    
    private func display(error: Error, at sourceRange: Range<String.Index>) {
        guard
            let textStorage = textView.textStorage,
            textStorage.string.range.contains(sourceRange)
        else {
            return
        }
        let textStorageRange = NSRange(sourceRange, in: textStorage.string)
        
        removeErrorDisplay()
        
        textStorage.addAttribute(.backgroundColor, value: NSColor(named: "ErrorHighlightColor")!, range: textStorageRange)
        textView.typingAttributes = defaultSourceCodeAttributes()
        
        let firstLineScreenRect = textView.firstRect(forCharacterRange: textStorageRange, actualRange: nil)
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
        let text = textView.string
        guard let range = Range<String.Index>(nsrange, in: text) else {
            return
        }
        
        guard let program = program, modelSourceCode.range.contains(range) else {
            NotificationCenter.default.post(name: .selection, object: document)
            return
        }
        NotificationCenter.default.post(name: .selection, object: document, userInfo: [UserInfo.payload: range])
        
        let expressionsAtLocation = program.expressions(at: SourceLocation(range, source: modelSourceCode))
        guard !expressionsAtLocation.isEmpty else {
            return
        }
        
        NotificationCenter.default.post(name: .selectedExpression, object: self.document, userInfo: [UserInfo.payload: expressionsAtLocation.first! as Any])
    }
    
    func textDidEndEditing(_ notification: Notification) {
//        dismissSuggestionList()
    }
    
    func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
        if Defaults[.wordCompletionSuggestionsEnabled] {
            let text = textView.string
            let range = Range<String.Index>(charRange, in: text)!
            let partialWord = text[range]
            let beforePartialWord = text[..<range.lowerBound]
            let afterPartialWord = text[range.upperBound...]
            let words = NSMutableOrderedSet(array: beforePartialWord.split { $0.isWhitespace }.reversed())
            words.union(NSOrderedSet(array: afterPartialWord.split { $0.isWhitespace }))
            return words.compactMap { ($0 as! Substring).hasPrefix(partialWord) ? String($0 as! Substring) : nil }
        } else {
            return []
        }
    }
    
}

// MARK: Suggestion list
extension DocumentVC {
    
//    private func showSuggestionList(with suggestions: [SuggestionListItem]) {
//        guard !suggestions.isEmpty else {
//            self.dismissSuggestionList()
//            return
//        }
//
//        let vc = self.suggestionListWC.contentViewController as! SuggestionListVC
//        vc.documentVC = self
//        vc.representedObject = suggestions
//
//        self.repositionSuggestionWindow()
//
//        self.suggestionListWC.showWindow(self)
//    }
//
//    func apply(suggestion: AutoFixSuggestionListItem) {
//        suggestion.service.applyFix(suggestion.fix, toSource: document.sourceCode) { fixedSource in
//            if let fixedSource = fixedSource {
//                DispatchQueue.main.sync {
//                    self.setModelSourceCodeUndoable(fixedSource, actionName: "Apply Fix")
//                    self.displayedSourceCode = self.modelSourceCode
//                }
//            }
//        }
//    }
//
//    @objc private func repositionSuggestionWindow() {
//        guard
//            let window = suggestionListWC.window,
//            let selectedRange = textView.selectedRanges.first?.rangeValue
//        else {
//            return
//        }
//
//        var selectionOrigin = textView.firstRect(forCharacterRange: selectedRange, actualRange: nil).origin
//        selectionOrigin.y -= window.frame.height
//        window.setFrameOrigin(selectionOrigin)
//
//    }
//
//    private func dismissSuggestionList() {
//        suggestionListWC.close()
//    }
    
}
