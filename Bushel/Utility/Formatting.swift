import Foundation

extension String {
    
    public var startsWithVowel: Bool {
        guard let first = first else {
            return false
        }
        return "aeiou".contains(
            String(first).folding(
                    options: [.caseInsensitive, .diacriticInsensitive],
                    locale: nil
            ).first!
        )
    }
    
}
