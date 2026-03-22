import Testing
import Foundation
@testable import GlazeWMIndicator

@Suite("WorkspaceModel")
struct WorkspaceModelTests {
    @Test("Groups workspaces by monitor via parentId")
    @MainActor
    func testGroupsByMonitor() {
        let workspaces = [
            WorkspaceInfo(type: "workspace", id: "1", name: "1", displayName: nil, hasFocus: true, isDisplayed: true, parentId: "mon-1", children: [ChildContainer(type: "window", id: "w1")]),
            WorkspaceInfo(type: "workspace", id: "2", name: "2", displayName: nil, hasFocus: false, isDisplayed: true, parentId: "mon-2", children: [ChildContainer(type: "window", id: "w2")]),
            WorkspaceInfo(type: "workspace", id: "3", name: "3", displayName: nil, hasFocus: false, isDisplayed: false, parentId: "mon-1", children: [ChildContainer(type: "window", id: "w3")]),
        ]

        let model = WorkspaceModel()
        model.update(workspaces: workspaces)

        #expect(model.monitorGroups.count == 2)
        #expect(model.monitorGroups[0].workspaces.count == 2)
        #expect(model.monitorGroups[1].workspaces.count == 1)
    }

    @Test("Filters out inactive workspaces (no windows, not displayed)")
    @MainActor
    func testFiltersInactiveWorkspaces() {
        let workspaces = [
            WorkspaceInfo(type: "workspace", id: "1", name: "1", displayName: nil, hasFocus: true, isDisplayed: true, parentId: "mon-1", children: [ChildContainer(type: "window", id: "w1")]),
            WorkspaceInfo(type: "workspace", id: "2", name: "2", displayName: nil, hasFocus: false, isDisplayed: false, parentId: "mon-1", children: []),
        ]

        let model = WorkspaceModel()
        model.update(workspaces: workspaces)

        #expect(model.monitorGroups[0].workspaces.count == 1)
    }

    @Test("Displayed workspace without windows is still shown")
    @MainActor
    func testDisplayedWorkspaceWithoutWindowsIsShown() {
        let workspaces = [
            WorkspaceInfo(type: "workspace", id: "1", name: "1", displayName: nil, hasFocus: true, isDisplayed: true, parentId: "mon-1", children: []),
        ]

        let model = WorkspaceModel()
        model.update(workspaces: workspaces)

        #expect(model.monitorGroups[0].workspaces.count == 1)
    }
}
