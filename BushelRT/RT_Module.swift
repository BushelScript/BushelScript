import Bushel

/// A runtime object that acts as a command target.
public protocol RT_Module: RT_Object {
    
    /// Asks this module to handle the command specified by `arguments`.
    ///
    /// - Returns: If the command is handled, its result; otherwise, `nil`.
    func handle(_ arguments: RT_Arguments) throws -> RT_Object?
    
}
