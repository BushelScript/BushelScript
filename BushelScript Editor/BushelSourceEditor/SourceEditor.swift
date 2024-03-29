import AppKit
import Bushel
import BushelRT

public protocol SourceEditorDelegate: AnyObject {
    
    var sourceCode: String? { get set }
    var program: Program? { get set }
    var rt: Runtime? { get set }
    
    var languageID: String? { get }
    var documentURL: URL? { get }
    
    var indentMode: IndentMode? { get }
    var defaultFont: NSFont { get }
    var highlightStyles: HighlightStyles { get }
    
    var useLiveParsing: Bool { get }
    var useLiveErrors: Bool { get }
    var useWordCompletionSuggestions: Bool { get }
    
}

public class SourceEditor: NSViewController {
    
    public typealias Delegate = SourceEditorDelegate
    
    public var delegate: Delegate!
    
    public static func create(delegate: Delegate) -> SourceEditor {
        let storyboard = NSStoryboard(name: "SourceEditor", bundle: Bundle(for: self))
        let sourceEditor = storyboard.instantiateInitialController() as! SourceEditor
        sourceEditor.delegate = delegate
        return sourceEditor
    }
    
    @IBOutlet private var textView: NSTextView!
    
    /// Throws away all previous data fetched from the delegate and
    /// loads it afresh.
    ///
    /// **Delegate messages:**
    /// - To retrieve the source code:
    ///   - getter:sourceCode
    /// - To color the UI and configure the highlighter:
    ///   - getter:highlightStyles
    /// - To configure the parser:
    ///   - getter:languageID
    ///   - getter:documentURL
    /// - To propagate the parsed program:
    ///   - setter:program
    public func reload() {
        if let backgroundColor = typingAttributes[.backgroundColor] as? NSColor {
            textView.backgroundColor = backgroundColor
        }
        if let sourceCode = delegate.sourceCode {
            do {
                _ = try highlight(sourceCode)
            } catch {
                if let textStorage = self.textView.textStorage {
                    textStorage.addAttributes(self.typingAttributes, range: NSRange(location: 0, length: textStorage.length))
                }
            }
            resetTypingAttributes()
        }
    }
    
    private var runQueue = DispatchQueue(label: "Run program", qos: .userInitiated)
    
    /// Runs the Bushel program `program`.
    ///
    /// - Parameter program: The program to run.
    ///
    /// **Delegate messages:**
    /// - To propagate the `Runtime`:
    ///   - setter:rt
    ///
    /// **Notifications:**
    /// - To propagate the result on successful termination
    ///   - Name: .result
    ///   - Object: This source editor
    ///   - UserInfo:
    ///     - .payload: The resultant `RT_Object`
    public func run(_ program: Program) {
        runQueue.async {
            do {
                let rt = Runtime()
                self.delegate.rt = rt
                let result = try rt.run(program)
                NotificationCenter.default.post(name: .sourceEditorResult, object: self, userInfo: [UserInfo.payload: result])
                DispatchQueue.main.async {
                    self.removeInlineError()
                }
            } catch {
                self.displayError(error)
            }
        }
    }
    
    /// Parses `source` into a Bushel program as if by `parse(_:)`, then
    /// pretty prints the result, and finally highlights the syntax of the
    /// pretty printed version as if by `highlight(_:)`.
    ///
    /// - Parameter source: Source code to pretty print.
    /// - Throws: Errors thrown by the language parser.
    /// - Returns: The `Program` resulting from parsing `source`.
    ///
    /// **Delegate messages:**
    /// - To configure the parser:
    ///   - getter:languageID
    ///   - getter:documentURL
    /// - To propagate the pretty printed source code:
    ///   - setter:sourceCode
    /// - To configure the highlighter:
    ///   - getter:highlightStyles
    /// - To propagate the parsed program:
    ///   - setter:program
    public func prettyPrint(_ source: String) throws -> Program {
        removeInlineError()
        
        let program = try parse(source)
        let pretty = Bushel.prettyPrint(program.elements)
        
        delegate.sourceCode = pretty
        return try highlight(pretty, registerUndo: true)
    }
    
    /// Parses `source` into a Bushel program as if by `parse(_:)`, then
    /// highlights the syntax of the result, asking the delegate for
    /// highlight styles.
    ///
    /// - Parameter source: Source code to parse and highlight.
    /// - Parameter registerUndo: Register changes as undoable?
    /// - Throws: Errors thrown by the language parser.
    /// - Returns: The `Program` resulting from parsing `source`.
    ///
    /// **Delegate messages:**
    /// - To configure the parser:
    ///   - getter:languageID
    ///   - getter:documentURL
    /// - To configure the highlighter:
    ///   - getter:highlightStyles
    /// - To propagate the parsed program:
    ///   - setter:program
    public func highlight(_ source: String, registerUndo: Bool = false) throws -> Program {
        func setDisplayedSourceCodeRespectingUndo(_ newValue: NSAttributedString) {
            if !registerUndo, let undoManager = undoManager {
                undoManager.withoutRegistration {
                    self.setDisplayedSourceCode(newValue)
                }
            } else {
                self.setDisplayedSourceCode(newValue)
            }
        }
        
        removeInlineError()
        do {
            let program = try parse(source)
            setDisplayedSourceCodeRespectingUndo(Bushel.highlight(source: Substring(source), program.elements, with: delegate.highlightStyles.highlighted))
            return program
        } catch {
            setDisplayedSourceCodeRespectingUndo(NSAttributedString(string: source, attributes: delegate.highlightStyles.unhighlighted))
            throw error
        }
    }
    
    /// Parses `source` into a Bushel program by asking the delegate
    /// for configuration, such as the language to use.
    ///
    /// - Parameter source: Source code to parse.
    /// - Throws: Errors thrown by the language parser.
    /// - Returns: The `Program` resulting from parsing `source`.
    ///
    /// **Delegate messages:**
    /// - To configure the parser:
    ///   - getter:languageID
    ///   - getter:documentURL
    /// - To propagate the parsed program:
    ///   - setter:program
    public func parse(_ source: String) throws -> Program {
        let program = try Bushel.parse(
            source: source,
            languageID: delegate.languageID,
            ignoringImports: delegate.documentURL.map { [$0] } ?? []
        )
        delegate.program = program
        return program
    }
    
    private func resetTypingAttributes() {
        textView.typingAttributes.merge(typingAttributes, uniquingKeysWith: { $1 })
    }
    
    private var typingAttributes: [NSAttributedString.Key : Any] {
        var attributes = delegate.highlightStyles.unhighlighted
        if attributes[.font] == nil {
            attributes[.font] = delegate.defaultFont
        }
        return attributes
    }
    
    private func setDisplayedSourceCode(_ newValue: NSAttributedString) {
        let selectedRanges = textView.selectedRanges
        let selectionAffinity = textView.selectionAffinity
        let selectionGranularity = textView.selectionGranularity
        defer {
            textView.setSelectedRanges(selectedRanges, affinity: selectionAffinity, stillSelecting: false)
            textView.selectionGranularity = selectionGranularity
        }
        
        guard textView.shouldChangeText(in: NSRange(location: 0, length: (textView.string as NSString).length), replacementString: newValue.string) else {
            return
        }
        
        textView.textStorage?.beginEditing()
        textView.textStorage?.setAttributedString(newValue)
        textView.textStorage?.endEditing()
        
        textView.didChangeText()
        resetTypingAttributes()
    }
    
    public func displayError(_ error: Error) {
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
    private lazy var inlineErrorVC = InlineErrorVC()
    
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
        
        inlineErrorVC.representedObject = inlineError.localizedDescription
        
        let errorView = inlineErrorVC.view
        textView.addSubview(errorView)
        
        let fontHeightAdjust = delegate.defaultFont.capHeight * 2.0
        errorView.frame.origin.y = firstLineFlippedRect.minY + errorView.frame.height + fontHeightAdjust
        errorView.leadingAnchor.constraint(greaterThanOrEqualTo: textView.leadingAnchor).isActive = true
        errorView.trailingAnchor.constraint(equalTo: textView.trailingAnchor).isActive = true
    }
    
    private func removeInlineError() {
        inlineError = nil
        removeInlineErrorView()
    }
    
    private func removeInlineErrorView() {
        inlineErrorVC.view.removeFromSuperview()
    }
    
    private var previousTabWidth: Int?
    
    private func updateTabWidth() {
        if indentMode.width == previousTabWidth {
            return
        }
        
        let paragraphStyle = textView.defaultParagraphStyle ?? NSParagraphStyle()
        let style = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        style.defaultTabInterval = NSAttributedString(string: String(repeating: " ", count: indentMode.width), attributes: textView.typingAttributes).size().width
        style.tabStops = []
        textView.defaultParagraphStyle = style
        textView.typingAttributes[.paragraphStyle] = style
        if let textStorage = textView.textStorage {
            textStorage.addAttributes([.paragraphStyle: style], range: NSRange(location: 0, length: textStorage.length))
        }
    }
    
    private var indentMode: IndentMode {
        delegate.indentMode ?? IndentMode()
    }
    
}

extension SourceEditor: NSTextViewDelegate {
    
    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let indentMode = delegate.indentMode ?? IndentMode()
        
        switch commandSelector {
        case #selector(insertTab(_:)),
             #selector(insertTabIgnoringFieldEditor(_:)):
            textView.insertText(indentMode.indentation, replacementRange: textView.selectedRange())
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
            lineIndentation = lineIndentation.replacingOccurrences(of: indentMode.indentation, with: "\t", options: [])
            let indentCount = lineIndentation.reduce(0) { $0 + ($1 == "\t" ? 1 : 0) }
            
            textView.insertNewline(self)
            textView.insertText(indentMode.indentation(for: indentCount), replacementRange: textView.selectedRange())
            return true
        default:
            return false
        }
    }
    
    public func textDidChange(_ notification: Notification) {
        let textView = notification.object as! NSText
        let newSource = textView.string
        
        if newSource != delegate.sourceCode {
            // This is an actual logical source code change, not merely
            // a change in formatting attibutes.
            delegate.sourceCode = newSource
            
            removeInlineError()
            if delegate.useLiveParsing {
                do {
                    _ = try highlight(newSource)
                } catch {
                    if delegate.useLiveErrors {
                        displayError(error)
                    }
                }
            } else {
                removeInlineError()
            }
        }
    }
    
    public func textViewDidChangeSelection(_ notification: Notification) {
        let ranges = textView.selectedRanges
        guard !ranges.isEmpty else {
            return
        }
        let nsrange = ranges[0].rangeValue
        let text = textView.string
        guard let range = Range<String.Index>(nsrange, in: text) else {
            return
        }
        
        guard
            let program = delegate.program,
            let sourceCode = delegate.sourceCode,
            sourceCode.range.contains(range)
        else {
            return
        }
        
        let expressionsAtLocation = program.expressions(at: SourceLocation(range, source: sourceCode))
        guard !expressionsAtLocation.isEmpty else {
            return
        }
        
        NotificationCenter.default.post(name: .sourceEditorSelectedExpressions, object: self, userInfo: [UserInfo.payload: expressionsAtLocation])
    }
    
    public func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
        if delegate.useWordCompletionSuggestions {
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

extension Notification.Name {
    
    public static let sourceEditorSelectedExpressions = Notification.Name("sourceEditorSelectedExpressions")
    public static let sourceEditorResult = Notification.Name("sourceEditorResult")

}
