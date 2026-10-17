import Foundation

struct TextReplacement: Codable, Identifiable, Equatable {
    var id: UUID
    var find: String
    var replace: String
    var isEnabled: Bool

    init(id: UUID = UUID(), find: String = "", replace: String = "", isEnabled: Bool = true) {
        self.id = id
        self.find = find
        self.replace = replace
        self.isEnabled = isEnabled
    }
}
