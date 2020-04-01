// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Defaults
import os

private let log = OSLog(subsystem: logSubsystem, category: "Dictionary document")

class DictionaryDocument: NSDocument {
    
    var dictionary: OSADictionary?
    
    override func makeWindowControllers() {
        guard let dictionary = dictionary else {
            return
        }
        guard let wc = OSADictionaryWindowController(dictionary: dictionary) else {
            os_log("Could not make OSADictionaryWindowContorller for dictionary named '%@'", log: log, type: .error, dictionary.name)
            return
        }
        wc.window?.title = "\(dictionary.name ?? "Unknown") Dictionary"
        addWindowController(wc)
    }
    
    override func write(to url: URL, ofType typeName: String) throws {
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnsupportedSchemeError, userInfo: [
            NSLocalizedFailureReasonErrorKey: "You cannot save a dictionary document."
        ])
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        dictionary = try OSADictionary(contentsOfURL: url)
    }
    
}
