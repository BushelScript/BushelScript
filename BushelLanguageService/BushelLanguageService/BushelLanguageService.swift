import Foundation
import Bushel
import BushelLanguage
import BushelRT

// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@objc(BushelLanguageService)
class BushelLanguageService: NSObject, BushelLanguageServiceProtocol {
    
    private var loadedLanguageModules = StoragePool<LanguageModule>()
    
    func loadLanguageModule(withIdentifier moduleIdentifier: String, reply: @escaping (Any?) -> Void) {
        guard let module = LanguageModule(identifier: moduleIdentifier) else {
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
    
    func parseSource(_ source: String, usingLanguageModule module: Any, reply: @escaping (Any?, Any?) -> Void) {
        guard let module = loadedLanguageModules[module] else {
            return reply(nil, nil)
        }
        do {
            let program = try module.parser().parse(source: source)
            reply(programs.retain(program), nil)
        } catch {
            reply(nil, errors.retain(error))
        }
    }
    
    func releaseProgram(_ program: Any, reply: @escaping (Bool) -> Void) {
        reply(programs.release(program))
    }
    
    func prettyPrintProgram(_ program: Any, reply: @escaping (String?) -> Void) {
        guard let program = programs[program] else {
            return reply(nil)
        }
        
        reply(program.source) // TODO: Fix pretty printing and re-enable
        _ = program
        
        // Code to use once pretty printing is fixed:
//        reply(program.ast.prettified(source: source))
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
    
    func runProgram(_ program: Any, scriptName: String?, currentApplicationID: String?, reply: @escaping (Any?) -> Void) {
        guard let program = programs[program] else {
            return reply(nil)
        }
        let rt = RTInfo(scriptName: scriptName, currentApplicationBundleID: currentApplicationID)
        reply(objects.retain(rt.run(program)))
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
        guard let error = errors[error] as? ParseError else {
            return reply(nil)
        }
        let range = error.location.lines(in: source)
        reply(NSValue(range: NSRange(range)))
    }
    func copyColumnRange(fromError error: Any, forSource source: String, reply: @escaping (NSValue?) -> Void) {
        guard let error = errors[error] as? ParseError else {
            return reply(nil)
        }
        let range = error.location.columns(in: source)
        reply(NSValue(range: NSRange(range)))
    }
    func copySourceCharacterRange(fromError error: Any, forSource source: String, reply: @escaping (NSValue?) -> Void) {
        guard let error = errors[error] as? ParseError else {
            return reply(nil)
        }
        let range = error.location.range
        reply(NSValue(range: NSRange(range, in: source)))
    }
    
    private var fixes = StoragePool<SourceFix>()
    
    func getSourceFixes(fromError error: Any, reply: @escaping ([Any]) -> Void) {
        guard let error = errors[error] as? ParseError else {
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
