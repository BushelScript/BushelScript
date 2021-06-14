import Foundation
import Bushel
import BushelRT

// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@objc(BushelLanguageService)
class BushelLanguageService: NSObject, BushelLanguageServiceProtocol {
    
    private var loadedLanguageModules = StoragePool<LanguageModule>()
    
    func loadLanguageModule(withIdentifier moduleIdentifier: String, reply: @escaping (Any?) -> Void) {
        guard let module = try? LanguageModule(identifier: moduleIdentifier) else {
            return reply(nil)
        }
        reply(loadedLanguageModules.retain(module))
    }
    
    func unloadLanguageModule(_ module: Any, reply: @escaping (Bool) -> Void) {
        reply(loadedLanguageModules.release(module))
    }
    
    private var programs = StoragePool<Program>()
    private var expressions = StoragePool<Expression>()
    private var errors = StoragePool<Error>()
    private var objects = StoragePool<RT_Object>()
    
    func parseSource(_ source: String, at url: URL?, usingLanguageModule module: Any, reply: @escaping (Any?, Any?) -> Void) {
        guard let module = loadedLanguageModules[module] else {
            return reply(nil, nil)
        }
        do {
            let program = try module.parser().parse(source: source, at: url)
            reply(programs.retain(program), nil)
        } catch {
            reply(nil, errors.retain(error))
        }
    }
    
    func releaseProgram(_ program: Any, reply: @escaping (Bool) -> Void) {
        reply(programs.release(program))
    }
    
    func highlightProgram(_ program: Any, reply: @escaping (Data?) -> Void) {
        guard let program = programs[program] else {
            return reply(nil)
        }
        
        let highlighted = highlight(source: Substring(program.source), program.elements, with: [
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
        ])
        
        reply(try? highlighted.data(from: NSRange(location: 0, length: (highlighted.string as NSString).length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]))
    }
    
    func prettyPrintProgram(_ program: Any, reply: @escaping (String?) -> Void) {
        guard let program = programs[program] else {
            return reply(nil)
        }
        
        reply(prettyPrint(program.elements))
    }
    
    func reformatProgram(_ program: Any, usingLanguageModule module: Any, reply: @escaping (String?) -> Void) {
        guard
            let module = loadedLanguageModules[module],
            let program = programs[program]
        else {
            return reply(nil)
        }
        reply(module.formatter().format(program.ast))
    }
    
    func getExpressionAtLocation(_ index: Int, inSourceOfProgram program: Any, reply: @escaping (Any?) -> Void) {
        guard let program = programs[program] else {
            return reply(nil)
        }
        let source = program.source
        let expressionsAtLocation = program.expressions(at: SourceLocation(at: source.index(source.startIndex, offsetBy: index), source: source))
        guard let expression = expressionsAtLocation.first else {
            return reply(nil)
        }
        reply(expressions.retain(expression))
    }
    
    func copyKindName(forExpression expression: Any, reply: @escaping (String?) -> Void) {
        guard let expression = expressions[expression] else {
            return reply(nil)
        }
        reply(expression.kindName)
    }
    
    func copyKindDescription(forExpression expression: Any, reply: @escaping (String?) -> Void) {
        guard let expression = expressions[expression] else {
            return reply(nil)
        }
        reply(expression.kindDescription)
    }
    
    func releaseExpression(_ expression: Any, reply: @escaping (Bool) -> Void) {
        reply(expressions.release(expression))
    }
    
    func runProgram(_ program: Any, arguments: [String], scriptName: String?, reply: @escaping (Any?, Any?) -> Void) {
        guard let program = programs[program] else {
            return reply(nil, nil)
        }
        let rt = Runtime(arguments: arguments, scriptName: scriptName)
        do {
            let result = try rt.run(program)
            reply(objects.retain(result), nil)
        } catch {
            reply(nil, errors.retain(error))
        }
    }
    
    func copyDescription(for object: Any, reply: @escaping (String?) -> Void) {
        guard let object = objects[object] else {
            return reply(nil)
        }
        reply(object.description)
    }
    
    // While at first glance it looks like we should just be vending an
    // Error in the first place, rather than an ErrorToken, the Error in this
    // reply block will be converted straight to NSError when sent over NSXPC.
    // Therefore, we lose any extra information it stores. We deal with this
    // by both vending an (NS)Error, and providing custom methods to work with
    // other data the error may have, such as source fixes.
    func copyNSError(fromError error: Any, reply: @escaping (Error) -> Void) {
        guard let error = errors[error] else {
            return
        }
        reply(error)
    }
    
    func releaseError(_ error: Any, reply: @escaping (Bool) -> Void) {
        reply(errors.release(error))
    }
    
    func copyLineRange(fromError error: Any, forSource source: String, reply: @escaping (NSValue?) -> Void) {
        guard let error = errors[error] as? Located else {
            return reply(nil)
        }
        let range = error.location.lines(in: source)
        reply(NSValue(range: NSRange(range)))
    }
    func copyColumnRange(fromError error: Any, forSource source: String, reply: @escaping (NSValue?) -> Void) {
        guard let error = errors[error] as? Located else {
            return reply(nil)
        }
        let range = error.location.columns(in: source)
        reply(NSValue(range: NSRange(range)))
    }
    func copySourceCharacterRange(fromError error: Any, forSource source: String, reply: @escaping (NSValue?) -> Void) {
        guard let error = errors[error] as? Located else {
            return reply(nil)
        }
        let range = error.location.range
        reply(NSValue(range: NSRange(range, in: source)))
    }
    
    private var fixes = StoragePool<SourceFix>()
    
    func getSourceFixes(fromError error: Any, reply: @escaping ([Any]) -> Void) {
        guard let error = errors[error] as? ParseErrorProtocol else {
            return reply([])
        }
        reply(error.fixes.map { fixes.retain($0) })
    }
    
    func copyContextualDescriptions(inSource source: String, fromFixes fixTokens: [Any], reply: @escaping ([String]) -> Void) {
        guard let fixes = fixes(from: fixTokens) else {
            return
        }
        let source = Substring(source)
        reply(fixes.map { $0.contextualDescription(in: source) })
    }
    
    func copySimpleDescriptions(inSource source: String, fromFixes fixTokens: [Any], reply: @escaping ([String]) -> Void) {
        guard let fixes = fixes(from: fixTokens) else {
            return
        }
        let source = Substring(source)
        reply(fixes.map { $0.simpleDescription(in: source) })
    }
    
    func applyFix(_ fix: Any, toSource source: String, reply: @escaping (String?) -> Void) {
        guard let fix = fixes[fix] else {
            return reply(source)
        }
        reply(try? fix.apply(to: source))
    }
    
    private func fixes(from fixTokens: [Any]) -> [SourceFix]? {
        let fixes = fixTokens.compactMap { self.fixes[$0] }
        guard fixes.count == fixTokens.count else {
            return nil
        }
        return fixes
    }
    
}

private class StoragePool<Stored> {
    
    private var pool: [Int : Stored] = [:]
    
    func retain(_ object: Stored) -> Any {
        let id = nextID()
        pool[id] = object
        return id
    }
    
    private var currentID = 0
    private func nextID() -> Int {
        defer { currentID += 1 }
        return currentID
    }
    
    subscript(id: Any) -> Stored? {
        guard
            let id = id as? Int,
            let object = pool[id]
        else {
            return nil
        }
        return object
    }
    
    func release(_ id: Any) -> Bool {
        guard let id = id as? Int else {
            return false
        }
        return pool.removeValue(forKey: id) != nil
    }
    
}
