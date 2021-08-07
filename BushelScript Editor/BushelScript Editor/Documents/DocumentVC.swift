// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Bushel
import BushelRT
import Defaults

class DocumentVC: NSViewController, NSUserInterfaceValidations, NSTextViewDelegate {
    
    @IBOutlet var textView: NSTextView!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    
    private var runQueue = DispatchQueue(label: "Run program", qos: .userInitiated)
    
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
                self.document.isRunning = (status == .running)
                self.statusText = status?.localizedDescription ?? ""
                self.isWorking = (status != nil)
            }
        }
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
    
    var customFontSize: CGFloat? {
        didSet {
            updateHighlightStyle()
        }
    }
    var documentFont: NSFont {
        if let customFontSize = customFontSize {
            return NSFontManager.shared.convert(
                Defaults[.sourceCodeFont],
                toSize: customFontSize
            )
        } else {
            return Defaults[.sourceCodeFont]
        }
    }
    
    var documentHighlightStyle: Styles = defaultSizeHighlightStyles ?? Styles()
    private func updateHighlightStyle() {
        documentHighlightStyle = (try? makeHighlightStyles(fontSize: customFontSize)) ?? Styles()
        rehighlight()
        if let backgroundColor = typingAttributes[.backgroundColor] as? NSColor {
            textView.backgroundColor = backgroundColor
        }
    }
    
    override func viewDidLoad() {
        Defaults.observe(.sourceCodeFont) { [weak self] _ in
            self?.updateHighlightStyle()
        }.tieToLifetime(of: self)
        Defaults.observe(.themeFileName) { [weak self] _ in
            self?.updateHighlightStyle()
        }.tieToLifetime(of: self)
    }
    
    private func rehighlight() {
        DispatchQueue.main.async {
            do {
                _ = try self.compile(self.modelSourceCode)
            } catch {
                if let textStorage = self.textView.textStorage {
                    textStorage.addAttributes(self.typingAttributes, range: NSRange(location: 0, length: textStorage.length))
                }
            }
        }
        resetTypingAttributes()
    }
    private func resetTypingAttributes() {
        textView.typingAttributes.merge(typingAttributes, uniquingKeysWith: { $1 })
    }
    
    private var typingAttributes: [NSAttributedString.Key : Any] {
        var attributes = documentHighlightStyle[.comment] ?? [:]
        if attributes[.font] == nil {
            attributes[.font] = Defaults[.sourceCodeFont]
        }
        return attributes
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
                
                resetTypingAttributes()
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
            displayedAttributedSourceCode = NSAttributedString(string: newValue, attributes: typingAttributes)
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
        guard newValue != modelSourceCode else {
            return
        }
        
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
    
    @objc private var document: Document! {
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
                        self.removeInlineError()
                        do {
                            _ = try self.compile(document.sourceCode)
                        } catch {
                            self.displayError(error)
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
    }
    
    @IBAction func setIndentType(_ sender: Any?) {
        guard
            let tag = (sender as AnyObject).tag,
            let character = IndentMode.Character(rawValue: tag)
        else {
            return
        }
        document.indentMode.character = character
    }
    @IBAction func setIndentWidth(_ sender: Any?) {
        guard let tag = (sender as AnyObject).tag else {
            return
        }
        document.indentMode.width = tag
        updateTabWidth()
    }
    
    private func updateTabWidth() {
        let paragraphStyle = textView.defaultParagraphStyle ?? NSParagraphStyle()
        let style = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        style.defaultTabInterval = NSAttributedString(string: String(repeating: " ", count: document.indentMode.width), attributes: textView.typingAttributes).size().width
        style.tabStops = []
        textView.defaultParagraphStyle = style
        textView.typingAttributes[.paragraphStyle] = style
        if let textStorage = textView.textStorage {
            textStorage.addAttributes([.paragraphStyle: style], range: NSRange(location: 0, length: textStorage.length))
        }
    }
    
    @objc func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(runScript(_:)):
            return !document.isRunning
        case #selector(terminateScript(_:)):
            return document.isRunning
        default:
            return true
        }
    }
    
    @IBAction func reloadResources(_ sender: Any?) {
        Bushel.globalCache.clearCache()
        do {
            _ = try compile(modelSourceCode)
        } catch {
            displayError(error)
        }
    }
    
    @IBAction func runScript(_ sender: Any?) {
        removeInlineError()
        
        let program: Program
        do {
            program = try Defaults[.prettyPrintBeforeRunning] ?
                self.prettyPrint(self.modelSourceCode) :
                self.compile(self.modelSourceCode)
        } catch {
            self.displayError(error)
            return
        }
        
        runQueue.async {
            self.statusStack.append(.running)
            defer {
                self.statusStack.removeLast()
            }
            do {
                self.document.rt = Runtime()
                let result = try self.document.rt.run(program)
                NotificationCenter.default.post(name: .result, object: self.document, userInfo: [UserInfo.payload: result])
                DispatchQueue.main.async {
                    self.removeInlineError()
                }
            } catch {
                self.displayError(error)
            }
        }
    }
    
    @IBAction func terminateScript(_ sender: Any?) {
        document.rt.shouldTerminate = true
    }
    
    @IBAction func prettyPrint( _ sender: Any?) {
        removeInlineError()
        do {
            _ = try prettyPrint(modelSourceCode)
        } catch {
            displayError(error)
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
        
        let highlighted = NSMutableAttributedString(attributedString: highlight(source: Substring(source), program.elements, with: documentHighlightStyle))
        
        self.document.undoManager?.disableUndoRegistration()
        defer {
            self.document.undoManager?.enableUndoRegistration()
        }
        self.displayedAttributedSourceCode = highlighted
        
        return program
    }
    
    private func parse(_ source: String) throws -> Program {
        let program = try Bushel.parse(source: source, languageID: document.languageID, ignoringImports: document.fileURL.map { [$0] } ?? [])
        document.program = program
        return program
    }
    
    @IBOutlet weak var sidebarObjectInspectorView: NSView!
    
    private var inlineErrorVC: InlineErrorVC?
    
    var selectedExpression: Expression?
    
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(insertTab(_:)),
             #selector(insertTabIgnoringFieldEditor(_:)):
            textView.insertText(document.indentMode.indentation, replacementRange: textView.selectedRange())
            return true
        case #selector(insertNewline(_:)):
            guard let textStorage = textView.textStorage else {
                return false
            }
            
            let selectedRange = textView.selectedRange()
            var lineBreakNSRange = (textStorage.string as NSString).rangeOfCharacter(from: .newlines, options: [.backwards], range: NSRange(location: 0, length: selectedRange.location))
            if lineBreakNSRange.location == NSNotFound {
                lineBreakNSRange = NSRange(location: 0, length: 0)
            }
            var firstNonspaceNSRange = NSRange(location: NSNotFound, length: 0)
            if selectedRange.location > lineBreakNSRange.location {
                firstNonspaceNSRange = (textStorage.string as NSString).rangeOfCharacter(from: CharacterSet.whitespaces.inverted, options: [], range: NSRange(location: lineBreakNSRange.location + 1, length: selectedRange.location - (lineBreakNSRange.location + 1)))
            }
            if firstNonspaceNSRange.location == NSNotFound {
                firstNonspaceNSRange = NSRange(location: selectedRange.location, length: 0)
            }
            guard
                let lineBreakRange = Range(lineBreakNSRange, in: textStorage.string),
                let firstNonspaceRange = Range(firstNonspaceNSRange, in: textStorage.string)
            else {
                return false
            }
            
            var lineIndentation = String(textStorage.string[lineBreakRange.upperBound..<firstNonspaceRange.lowerBound])
            lineIndentation = lineIndentation.replacingOccurrences(of: document.indentMode.indentation, with: "\t", options: [])
            let indentCount = lineIndentation.reduce(0) { $0 + ($1 == "\t" ? 1 : 0) }
            
            textView.insertNewline(self)
            textView.insertText(document.indentMode.indentation(for: indentCount), replacementRange: textView.selectedRange())
            return true
        default:
            return false
        }
    }
    
    func textDidChange(_ notification: Notification) {
        if textView.string != modelSourceCode {
            sourceCodeChanged()
        }
    }
    
    private func sourceCodeChanged() {
        removeInlineError()
        
        let source = textView.string
        modelSourceCode = source
        
        removeInlineError()
        if Defaults[.liveParsingEnabled] {
            do {
                _ = try compile(source)
            } catch {
                if Defaults[.liveErrorsEnabled] {
                    displayError(error)
                }
            }
        }
    }
    
    private func displayError(_ error: Error) {
        DispatchQueue.main.async {
            guard let located = error as? (Error & Located) else {
                self.presentError(error)
                return
            }
            self.inlineError = located
            self.displayInlineError()
        }
    }
    
    private var inlineError: (Error & Located)?
    
    private func displayInlineError() {
        guard let inlineError = inlineError else {
            return
        }
        
        removeInlineErrorView()
        let sourceRange = inlineError.location.range
        
        guard
            let textStorage = textView.textStorage,
            textStorage.string.range.contains(sourceRange)
        else {
            return
        }
        let textStorageRange = NSRange(sourceRange, in: textStorage.string)
        
        textStorage.addAttribute(.backgroundColor, value: NSColor(named: "ErrorHighlightColor")!, range: textStorageRange)
        resetTypingAttributes()
        
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
            CGAffineTransform(translationX: 0, y: textView.enclosingScrollView!.documentVisibleRect.maxY)
                .scaledBy(x: 1, y: -1)
        )
        
        let inlineErrorVC = InlineErrorVC()
        self.inlineErrorVC = inlineErrorVC
        inlineErrorVC.representedObject = inlineError.localizedDescription
        
        let errorView = inlineErrorVC.view
        textView.addSubview(errorView)
        
        let fontHeightAdjust = documentFont.capHeight * 2.0
        errorView.frame.origin.y = firstLineFlippedRect.minY + errorView.frame.height + fontHeightAdjust
        errorView.leadingAnchor.constraint(greaterThanOrEqualTo: textView.leadingAnchor).isActive = true
        errorView.trailingAnchor.constraint(equalTo: textView.trailingAnchor).isActive = true
    }
    
    private func removeInlineError() {
        inlineError = nil
        removeInlineErrorView()
    }
    
    private func removeInlineErrorView() {
        guard let oldInlineErrorVC = self.inlineErrorVC else {
            return
        }
        self.inlineErrorVC = nil
        oldInlineErrorVC.view.removeFromSuperview()
    }
    
    func textViewDidChangeSelection(_ notification: Notification) {
        textViewDidChangeSelection()
    }

    private func textViewDidChangeSelection() {
        guard let document = document else {
            return
        }
        
        let ranges = textView.selectedRanges
        guard !ranges.isEmpty else {
            return
        }
        let nsrange = ranges[0].rangeValue
        let text = textView.string
        guard let range = Range<String.Index>(nsrange, in: text) else {
            return
        }
        
        guard let program = document.program, modelSourceCode.range.contains(range) else {
            NotificationCenter.default.post(name: .selection, object: document)
            return
        }
        NotificationCenter.default.post(name: .selection, object: document, userInfo: [UserInfo.payload: range])
        
        let expressionsAtLocation = program.expressions(at: SourceLocation(range, source: modelSourceCode))
        guard !expressionsAtLocation.isEmpty else {
            return
        }
        
        document.selectedExpressions = expressionsAtLocation
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
