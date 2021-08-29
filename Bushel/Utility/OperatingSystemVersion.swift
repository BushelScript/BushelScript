import Foundation
import Regex

extension OperatingSystemVersion: LosslessStringConvertible {
    
    public static let dottedDecimalRegex = Regex("[vV]?(\\d+)\\.(\\d+)(?:\\.(\\d+))?")
    
    public init?(_ versionString: String) {
        guard let match = Self.dottedDecimalRegex.firstMatch(in: versionString) else {
            return nil
        }
        self.init(dottedDecimalRegexMatch: match)
    }
    
    public init(dottedDecimalRegexMatch match: MatchResult) {
        let versionComponents = match.captures.compactMap { $0.map { Int($0)! } }
        self.init(
            majorVersion: versionComponents[0],
            minorVersion: versionComponents[1],
            patchVersion: versionComponents.count > 2 ? versionComponents[2] : 0
        )
    }
    
    public var description: String {
        "\(majorVersion).\(minorVersion).\(patchVersion)"
    }
    
}
