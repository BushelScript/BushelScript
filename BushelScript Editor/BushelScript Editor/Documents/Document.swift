// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Defaults
import Bushel
import BushelRT
import os

private let log = OSLog(subsystem: logSubsystem, category: "Document read/write")

class Document: NSDocument {
    
    @objc var sourceCode: String = ""
    @objc dynamic var languageID: String = "bushelscript_en" {
        didSet {
            program = nil
        }
    }
    @objc dynamic var indentMode = IndentMode()
    
    var program: Bushel.Program?
    var selectedExpressions: [Expression] = []
    var rt = BushelRT.Runtime()
    
    @objc dynamic var isRunning: Bool = false {
        didSet {
            let ad = NSApplication.shared.delegate as! AppDelegate
            if isRunning {
                ad.runningDocuments.insert(self)
            } else {
                ad.runningDocuments.remove(self)
            }
        }
    }
    
    override func close() {
        rt.shouldTerminate = true
        (NSApplication.shared.delegate as? AppDelegate)?.runningDocuments.remove(self)
        super.close()
    }
    
    // Thank you to https://gist.github.com/keith/a0388486714ca91c27e1848b2f6b8306
    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        guard
            let selector = shouldCloseSelector,
            let context = contextInfo,
            let target = delegate as? NSObject,
            let imp = class_getMethodImplementation(type(of: target), selector)
        else {
            return super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
        }
        
        typealias DelegateMethodImp = @convention(c) (NSObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer) -> Void
        let impFn = unsafeBitCast(imp, to: DelegateMethodImp.self)
        
        if isRunning, let windowForSheet = windowForSheet {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Close and terminate script?"
            alert.informativeText = "This will terminate the running script."
            alert.addButton(withTitle: "Close and Terminate")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: windowForSheet) { response in
                let canClose = (response == .alertFirstButtonReturn)
                if canClose {
                    return super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
                } else {
                    impFn(target, selector, self, false, context)
                }
            }
        } else {
            return super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
        }
    }
    
    /// The hashbang string the document had when it was opened.
    /// If "Add hashbang on save" is disabled, this is used instead.
    private var originalHashbang: String? = nil
    
    override class var autosavesInPlace: Bool {
        true
    }
    
    override func makeWindowControllers() {
        let wc = NSStoryboard.main!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        wc.contentViewController!.representedObject = self
        self.addWindowController(wc)
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
        let saveString = buildHashbang() + sourceCode
        let data = saveString.data(using: .utf8)!
        
        try data.write(to: url, options: .atomic)
        
        let path = url.path
        if Defaults[.addHashbangOnSave] {
            let maybePerms: Int16?
            do {
                maybePerms = (try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber)?.int16Value
            } catch {
                os_log("Could not retrieve permissions for save target '%@': %@", log: log, path, String(describing: error))
                return
            }
            guard let perms = maybePerms else {
                os_log("Could not retrieve permissions for save target '%@': value was not of type NSNumber", log: log, path)
                return
            }
            
            let permsWithExecute = perms | 0o100 // u+x
            do {
                try FileManager.default.setAttributes([.posixPermissions: permsWithExecute], ofItemAtPath: path)
            } catch {
                os_log("Could not set permissions for save target '%@': %@", log: log, path, String(describing: error))
                return
            }
        }
    }
    
    private func buildHashbang() -> String {
        guard Defaults[.addHashbangOnSave] else {
            if let originalHashbang = originalHashbang {
                return originalHashbang + "\n\n"
            } else {
                return ""
            }
        }
        var hashbang = "#!\(Defaults[.addHashbangOnSaveProgram])"
        if Defaults[.addHashbangOnSaveUseLanguageFlag] {
            hashbang += " -l \(languageID)"
        }
        return hashbang + "\n\n"
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        // Insert code here to read your document from the given data of the specified type, throwing an error in case of failure.
        // Alternatively, you could remove this method and override read(from:ofType:) instead.
        // If you do, you should also override isEntireFileLoaded to return false if the contents are lazily loaded.
        
        var convertedString: NSString?
        _ = NSString.stringEncoding(for: data, encodingOptions: [.suggestedEncodingsKey: [NSNumber(value: String.Encoding.utf8.rawValue), NSNumber(value: String.Encoding.utf16.rawValue)]], convertedString: &convertedString, usedLossyConversion: nil)
        guard var readString = convertedString as String? else {
            throw ReadError.corruptData(reason: "Could not determine the encoding of the document's text.")
        }
        
        var firstLine = readString.prefix(while: { !$0.isNewline })
        firstLine.removeLeadingWhitespace()
        if firstLine.hasPrefix("#!") {
            let hashbang = String(firstLine)
            self.originalHashbang = hashbang
            
            let languageIDRegex = try! NSRegularExpression(pattern: "-l\\s*(\\w+)", options: [])
            if
                let match = languageIDRegex.firstMatch(in: hashbang, options: [], range: NSRange(hashbang.range, in: hashbang)),
                let languageIDRange = Range<String.Index>(match.range(at: 1), in: hashbang)
            {
                self.languageID = String(hashbang[languageIDRange])
            }
            
            readString = String(
                readString[hashbang.endIndex...]
                .drop(while: { $0.isNewline })
            )
        }
        
        self.sourceCode = readString
    }
    
}

class IndentMode: NSObject {
    
    @objc dynamic var character: Character = .tab
    @objc dynamic var width: Int = 4
    
    @objc enum Character: Int {
        case space, tab
    }
    
    var indentation: String {
        switch character {
        case .space:
            return String(repeating: " ", count: width)
        case .tab:
            return "\t"
        @unknown default:
            return String(repeating: " ", count: width)
        }
    }
    func indentation(for level: Int) -> String {
        String(repeating: indentation, count: level)
    }
    
}
