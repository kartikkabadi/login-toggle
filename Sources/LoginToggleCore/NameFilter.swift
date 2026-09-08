import Foundation

// Name visibility predicate shared by the menu's live and saved item lists.
// Rejects empty, whitespace-only, and Unicode format/control-only names (any
// Cc/Cf scalar); keeps emoji and punctuation.
public func hasVisibleName(_ s: String) -> Bool {
    let skip = CharacterSet.whitespacesAndNewlines.union(CharacterSet.controlCharacters)
    return s.unicodeScalars.contains { !skip.contains($0) }
}
