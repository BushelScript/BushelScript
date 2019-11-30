import Foundation

/// Planned but currently unused. Intended to format error messages according
/// to the represented human language. This could be done with strings files instead…
public protocol MessageFormatter {
    
    func format(error: ParseError) -> String
    
    init()
    
}
