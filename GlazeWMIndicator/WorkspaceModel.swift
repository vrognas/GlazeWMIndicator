import Foundation

struct MonitorGroup: Identifiable {
    let id: String
    let workspaces: [WorkspaceInfo]
}

@MainActor
class WorkspaceModel: ObservableObject {
    @Published var monitorGroups: [MonitorGroup] = []

    func update(workspaces: [WorkspaceInfo]) {
        let active = workspaces.filter { $0.hasWindows || $0.isDisplayed }

        var seen: [String: [WorkspaceInfo]] = [:]
        var order: [String] = []
        for ws in active {
            if seen[ws.parentId] == nil {
                order.append(ws.parentId)
            }
            seen[ws.parentId, default: []].append(ws)
        }

        monitorGroups = order.map { MonitorGroup(id: $0, workspaces: seen[$0]!) }
    }
}
