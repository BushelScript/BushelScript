// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Defaults
import os

private let log = OSLog(subsystem: logSubsystem, category: "Document read/write")

class Document: NSDocument {
    
    @objc var sourceCode: String = "" {
        didSet {
            updateChangeCount(.changeDone)
        }
    }
    @objc dynamic var languageID: String = "bushelscript_en"
    
    var isRunning: Bool = false
    
    /// The hashbang string the document had when it was opened.
    /// If "Add hashbang on save" is disabled, this is used instead.
    private var originalHashbang: String? = nil
    
    override class var autosavesInPlace: Bool {
        true
    }
    
    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
        windowController.contentViewController!.representedObject = self
        self.addWindowController(windowController)
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
