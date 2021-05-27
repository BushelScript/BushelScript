import Foundation

/// An Abstract Syntax Tree (AST) node of a Bushel language program.
public struct Expression {
    
    /// An expression's kind and constituents, like terms and subexpressions,
    /// which vary by kind.
    public indirect enum Kind {
        /// Syntactically groups its constituent. Evaluates it and yields the
        /// result.
        case parentheses(Expression)
        /// Pushes an anonymous dictionary _D_ to the lexicon, evaluates its
        /// constituent, and then pops _D_ off the lexicon. Yields the result
        /// of evaluating its constituent.
        case scoped(Expression)
        /// Evaluates each constituent expression in order and yields the result
        /// of the last one.
        case sequence([Expression])
        /// Represents a blank line in a sequence. Yields the equivalent of
        /// `.that`.
        case empty
        /// Yields the result of the previous evaluated expression in the
        /// current sequence.
        case that
        /// Yields the current target.
        case it
        /// Evaluates `target` without evaluating specifiers, makes the result
        /// the current target, evalutes `to`, and then reverts the current
        /// target.
        case tell(target: Expression, to: Expression)
        /// Imports the resource identified by `resource`.
        /// See [Resources](https://bushelscript.github.io/help/docs/ref/resources).
        case use(resource: Term)
        /// Yields the resource identified by its constituent term.
        case resource(Term)
        /// Yields the null constant.
        case null
        /// Yields an integer object with its constituent value.
        case integer(Int64)
        /// Yields a double-precision floating-point number object with its
        /// constituent value.
        case double(Double)
        /// Yields a string object with its constituent value.
        case string(String)
        /// Yields a string object with `body` as its (possibly multiline)
        /// value.
        case multilineString(bihash: Bihash, body: String)
        /// Evaluates each of its constituent expressions in order, and yields
        /// a list object containing their results.
        case list([Expression])
        /// Evaluates each of its constituent key-value pairs in order by:
        ///  - Evaluating the key without evaluating specifiers, then
        ///  - Evaluating the value.
        ///
        /// Yields a record object mapping the result keys to the result values.
        case record([(key: Expression, value: Expression)])
        /// Yields the value bound to its constituent variable term.
        case variable(Term)
        /// Yields a constant object reflecting its constituent term.
        case enumerator(Term)
        /// Yields a type object reflecting its constituent term.
        case type(Term)
        /// Builds a specifier object from its constituent specifier, evaluting
        /// all of its expressions in order.
        /// If the current context evaluates specifiers, evaluates the specifier
        /// object and yields the result.
        /// Otherwise, yields the specifier object.
        case specifier(Specifier)
        /// Builds an insertion specifier object from its constituent insertion
        /// specifier, evaluating all of its expressions in order, and yields
        /// the insertion specifier object.
        case insertionSpecifier(InsertionSpecifier)
        /// Evaluates `to` without evaluating specifiers and yields the result.
        case reference(to: Expression)
        /// Evaluates its constituent, evaluating specifiers, and yields the
        /// result.
        case get(Expression)
        /// If its constituent is a `.variable` expression, evaluates `to` and
        /// binds the result to the `.variable` expression's variable term.
        /// Otherwise, evaluates its constituent _C_ without evaluating
        /// specifiers, evaluates `to`, and calls the command `ae8:coresetd`
        /// with the result of _C_ as the direct object argument and the result
        /// of `to` as the `ae4:data` argument.
        case set(Expression, to: Expression)
        /// Evaluates each `value` expression in `parameters`, then calls its
        /// constituent command term with the result of each `value` as the argument for its key-value pair's `key` parameter term. Yields the
        /// result of the call.
        case command(Term, parameters: [(key: Term, value: Expression)])
        /// Evaluates `operand`, then yields `operation` applied to the result.
        case prefixOperator(operation: UnaryOperation, operand: Expression)
        /// Evaluates `operand`, then yields `operation` applied to the result.
        case postfixOperator(operation: UnaryOperation, operand: Expression)
        /// Evaluates `lhs`, then `rhs`, and then yields `operation` applied
        /// to the result of `lhs` and the result of `rhs`.
        case infixOperator(operation: BinaryOperation, lhs: Expression, rhs: Expression)
        /// Performs the equivalent of the following:
        ///  - Creates an executable temporary file _F_ with `hashbang`'s
        ///    invocation as a `#!` signature and with no other content.
        ///  - Appends `body` to _F_.
        ///  - Requests that the OS execute _F_, establishing communication with
        ///    the newly created process _P_ via stdin pipe _I_ and stdout pipe
        ///    _O_.
        ///  - Writes the equivalent of `.that` coereced to a string to _I_ and
        ///    then closes _I_.
        ///  - Blocks until _P_ has terminated.
        ///  - Yields the entire contents of _O_ as a string.
        case weave(hashbang: Hashbang, body: String)
        /// Defines the constituent variable term in the current dictionary.
        /// If `initialValue` exists, evaluates `initialValue` and binds the
        /// result to the constituent variable term.
        case let_(Term, initialValue: Expression?)
        /// Let _T_ be a term with the role and name of the constituent term.
        /// If `as` exists, _T_ has the URI of `as`.
        /// Otherwise, _T_ has a pathname URI composed of its name and the
        /// name of each dictionary in the lexicon, in order.
        /// Defines _T_ in the current dictionary.
        /// Yields the equivalent of `.that`.
        case define(Term, as: Term?)
        /// Semantically equivalent to _.define_, except that after defining
        /// _T_, pushes _T_'s dictionary _D_ on the lexicon, evaluates `body`,
        /// and then pops _D_ off the lexicon. Yields the result of `body`.
        case defining(Term, as: Term?, body: Expression)
        /// Defines a function by adding `name` to the current dictionary as a
        /// command term with parameter terms `parameters`.
        ///
        /// When evaluated, adds a function with the signature identified by
        /// `name`, `parameters`, and the result of each expression in `types`
        /// to the current module.
        ///
        /// `body` is the function definition.
        /// An invocation of the function performs the following relevant
        /// actions:
        ///  - Binds each argument to its matching variable term in `arguments`.
        ///  - Evaluates `body` and yields its result.
        ///
        /// Yields the equivalent of `.that`.
        case function(name: Term, parameters: [Term], types: [Expression?], arguments: [Term], body: Expression)
        /// Defines an anonymous function that takes a single parameter of type
        /// `ae4:list`.
        /// (Note that this does not add the function to any module.)
        ///
        /// `body` is the function definition.
        /// An invocation of the function performs the following relevant
        /// actions:
        ///  - Given direct argument object _O_, coerces _O_ to a list _L_
        ///    and binds the items in _L_ to each variable term in `arguments`,
        ///    in order.
        ///    If _L_ is longer than `arguments`, discards the rest of _L_.
        ///    If _L_ is shorter than `arguments`, binds null to each of
        ///    the rest of the variable terms in `arguments`.
        ///    If no direct argument is given, _O_ is an empty list.
        ///  - Evaluates `body` and yields its result.
        ///
        /// Yields the function object.
        case block(arguments: [Term], body: Expression)
        /// Evaluates its constituent _C_ if it exists, then returns control
        /// from the current function context.
        /// If _C_ exists, the function yields the result of _C_.
        /// Otherwise, the function yields the equivalent of `.that`.
        case return_(Expression?)
        /// Evaluates its constituent and raises the result as an error.
        case raise(Expression)
        /// Evaluates `body`. If an error is raised while evaluating `body`,
        /// makes the raised object the current target, evaluates `handle`, and
        /// then reverts the current target.
        case try_(body: Expression, handle: Expression)
        /// _Conditional expression_.
        ///
        /// Evaluates `condition`.
        /// If the result is truthy, evaluates `then` and yields its result.
        /// Otherwise:
        ///   - If `else` exists, evaluates `else` and yields its result.
        ///   - Otherwise, yields the equivalent of `.that`.
        case if_(condition: Expression, then: Expression, else: Expression?)
        /// _Indefinite loop expression_.
        ///
        /// Evaluates `condition`.
        /// If the result is truthy:
        ///  - (A) Evalutes `repeating`. Then, evaluates `condition`:
        ///    - If the result of `condition` is truthy, continues from
        ///      line (A).
        ///    - Otherwise, yields the result of the last evaluation of
        ///      `repeating`.
        ///
        ///  Otherwise, yields the equivalent of `.that`.
        case repeatWhile(condition: Expression, repeating: Expression)
        /// _Definite counting loop expression_.
        ///
        /// Evaluates `times`.
        ///
        /// If the result of `times` is numeric, let _n_ be that number rounded
        /// to an integer toward positive infinity.
        /// Then:
        ///  - Evaluates `repeating`.
        ///  - If `repeating` has been evaluated _n_ times, yields the result of
        ///    the last evaluation of `repeating`.
        ///
        /// Otherwise (if the result of `times` is not numeric), yields the
        /// equivalent of `.that`.
        case repeatTimes(times: Expression, repeating: Expression)
        /// _Definite iterating loop expression_.
        ///
        /// Evaluates `container`.
        ///
        /// If the result of `container` is a sequence, let _n_ be the length
        /// of that seuqnece.
        /// Then:
        ///  - Binds the element at zero-based index _i_ of the sequence to the
        ///    variable term `variable`, where _i_ is the number of times
        ///    `repeating` has been evaluated.
        ///  - Evaluates `repeating`.
        ///  - If `repeating` has been evaluated _n_ times, yields the result of
        ///    the last evaluation of `repeating`.
        ///
        /// Otherwise (if the result of `container` is not a sequence), raises
        /// some error.
        case repeatFor(variable: Term, container: Expression, repeating: Expression)
        
        case debugInspectTerm(term: Term, message: String)
        case debugInspectLexicon(message: String)
    }
    
    /// Kind and constituents, including terms and subexpressions.
    public let kind: Kind
    /// Location in the source code from which the expression was parsed.
    public let location: SourceLocation
    
    /// Initializes from constituent kind and location.
    public init(_ kind: Kind, at location: SourceLocation) {
        self.kind = kind
        self.location = location
    }
    
}

extension Expression {
    
    /// Whether evaluating the expression may have any detectable effects other
    /// than yielding a value (side-effects).
    ///
    /// Simple constant and read expressions do not have side-effects.
    ///
    /// Many expressions do not intrinsically have side-effects but do have
    /// subexpressions. Such expressions may have side-effects if and only if
    /// any of their subexpressions have side-effects.
    ///
    /// Some kinds of expression intrinsically may have side-effects. This is
    /// usually due to some uncontrolled external interaction (like `.command`).
    public var hasSideEffects: Bool {
        switch kind {
        case .empty, .that, .it, .null, .resource, .integer, .double, .string, .variable, .enumerator, .type, .multilineString, .debugInspectTerm, .debugInspectLexicon:
            assert(subexpressions().isEmpty)
            return false
        case .sequence, .scoped, .parentheses, .function, .block, .try_, .if_, .repeatWhile, .repeatTimes, .repeatFor, .tell, .let_, .define, .defining, .return_, .raise, .list, .record, .specifier, .insertionSpecifier, .reference, .get:
            return subexpressions().contains(where: { $0.hasSideEffects })
        case .use, .prefixOperator, .postfixOperator, .infixOperator, .set, .command, .weave:
            return true
        }
    }
    
}

public extension Expression {
    
    var kindName: String {
        kind.kindName
    }
    
    var kindDescription: String {
        kind.kindDescription
    }
    
}

extension Expression.Kind {
    
    public var kindName: String {
        kindDescriptionStrings.kindName
    }
    
    public var kindDescription: String {
        kindDescriptionStrings.kindDescription
    }
    
    private var kindDescriptionStrings: (kindName: String, kindDescription: String) {
        switch self {
        case .empty:
            return ("Empty expression", "No effect.")
        case .that:
            return ("Previous result specifier", "Specifies the result of the last expression executed in sequence.")
        case .it:
            return ("Current target specifier", "Specifies the current command target, as set by the nearest “tell” block.")
        case .null:
            return ("Null literal", "The absence of a value.")
        case .sequence:
            return ("Sequence", "A list of sequentially evaluated expressions.")
        case .scoped:
            return ("Scoped block expression", "Provides a local dictionary that pops off the lexicon when the expression ends.")
        case .parentheses:
            return ("Parenthesized expression", "Contains an expression to allow for grouping.")
        case .try_:
            return ("Try expression", "Executes the contained block. If an error is raised during that execution, executes its “handle” block.")
        case .if_:
            return ("Conditional expression", "Evaluates its condition. When the result is truthy, executes its “then” block. Otherwise, executes its ”else” block, if any.")
        case .repeatWhile:
            return ("Conditional repeat expression", "Executes the contained block as long as its condition is truthy.")
        case .repeatTimes:
            return ("Constant-bounded repeat expression", "Evaluates its ”times“ expression, then executes the contained block that many times.")
        case .repeatFor:
            return ("Iterative repeat expression", "Executes the contained block for each element in the specified collection.")
        case .tell:
            return ("Tell expression", "Changes the current command target and pushes the new target’s dictionary, if any, onto the lexicon.")
        case .let_:
            return ("Variable binding expression", "Defines a new variable term and assigns it the result of the initial value expression, or “null” if absent.")
        case .define:
            return ("Define expression", "Defines a new term in the current dictionary.")
        case .defining:
            return ("Defining expression", "Defines a new term in the current dictionary, and elaborates on its contents by opening a block where it is the new current dictionary (i.e., is pushed onto the lexicon).")
        case .function:
            return ("Function definition", "Defines a custom, reusable function.")
        case .block:
            return ("Block expression", "An anonymous function.")
        case .return_:
            return ("Return expression", "Immediately transfers control out of the current function. The result of the function is that of the specified expression, or “null” if absent.")
        case .raise:
            return ("Raise expresssion", "Immediately transfers control to the nearest applicable ‘handle’-block. The error object is specified here.")
        case .use:
            return ("Use expression", "Acquires the specified resource and binds it to an exporting term of the same name. Produces a compile-time error if the resource cannot be found.")
        case .resource:
            return ("Resource reference", "A resource declared by a “use” statement.")
        case .integer:
            return ("Integer literal", "An integer with the specified value.")
        case .double:
            return ("Real literal", "A double-precision floating point number (roughly, a real number) with the specified value.")
        case .string:
            return ("String literal", "A string representing the specified text.")
        case .list:
            return ("List literal", "A heterogeneous list of items.")
        case .record:
            return ("Record literal", "A heterogeneous list of keys and values, indexed by key and stored as a hash table. Converts to an AppleScript-style record (with four-byte code keys) if possible when sent in an AppleEvent.")
        case .prefixOperator:
            return ("Prefix operator", "")
        case .postfixOperator:
            return ("Postfix operator", "")
        case .infixOperator:
            return ("Infix operator", "")
        case .variable:
            return ("Variable reference", "A previously defined variable.")
        case .enumerator:
            return ("Constant reference", "An enumerated, symbolic constant whose semantics depend on the context of use.")
        case .type:
            return ("Type reference", "A BushelScript type value.")
        case .specifier:
            return ("Specifier", "Refers to one or more object(s). Can be evaluated with a “get” command or passed around as a reference. Automatically evaluated in most contexts; use a reference expression to prevent this.")
        case .insertionSpecifier:
            return ("Insertion specifier", "Refers to a position in an ordered collection at which an object could be inserted.")
        case .reference:
            return ("Reference expression", "Prevents the automatic evaluation of a specifier, producing an unevaluated reference as an object.")
        case .get:
            return ("Get command", "Explicitly evaluates a specifier, even in a nonevaluating context.")
        case .set:
            return ("Set command", "Assigns a new value to the target expression. The target may be a variable or a local or remote property.")
        case .command:
            return ("Command invocation", "Invokes the specified command with the given arguments.\n\nIf there is no direct object, the current command target is used as the direct object. First, asks the direct object to perform the command. If it cannot handle the command, and the current command target was not used as the direct object, asks the current command target to perform the command. In either case, if the command has still not been handled, asks the built-in top-level command target to perform the command.")
        case .multilineString:
            return ("Multiline string", "A string representing the specified multiline text; a heredoc.\n\nMultiline strings are an experimental feature and are likely to change with time.")
        case .weave:
            return ("Weave expression", "Calls out to an external shell program using the given hashbang line.\n\nInput and output: The result of the previous expression is coerced to a string and written to standard input; the weave expression’s result is a string containing whatever the program writes to standard output.\n\nHashbangs: If the hashbang line begins with a ‘/’, e.g., “#!/bin/sh”, it is used verbatim. Otherwise, the line is fed as input into ‘env’, e.g., “#!ruby” is transformed to “#!/usr/bin/env ruby”.\n\nEnding a weave: To end the weave, either write a new hashbang line with a different shell program, or write “#!” to return to the previous BushelScript context.\n\nWeaves are an experimental feature and are likely to change with time.")
        case .debugInspectTerm:
            return ("Debug: Inspect term", "A detailed description of the given term.")
        case .debugInspectLexicon:
            return ("Debug: Inspect lexicon", "A detailed description of the current lexicon.")
        }
    }
    
}
