import Foundation

struct WorkspaceInfo: Decodable, Identifiable {
    let type: String?
    let id: String
    let name: String
    let displayName: String?
    let hasFocus: Bool
    let isDisplayed: Bool
    let parentId: String
    let children: [ChildContainer]?

    var label: String {
        displayName ?? name
    }

    var hasWindows: Bool {
        guard let children else { return false }
        return !children.isEmpty
    }
}

struct ChildContainer: Decodable {
    let type: String
    let id: String
}
