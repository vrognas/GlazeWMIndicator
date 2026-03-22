import SwiftUI

struct WorkspaceButton: View {
    let workspace: WorkspaceInfo
    let onClick: (String) -> Void

    var body: some View {
        Image(nsImage: generateWorkspaceImage(
            label: workspace.label,
            active: workspace.hasFocus,
            visible: workspace.isDisplayed
        ))
        .onTapGesture {
            onClick(workspace.name)
        }
        .frame(width: 24, height: 16)
    }
}

struct ContentView: View {
    @EnvironmentObject var model: WorkspaceModel
    var onWorkspaceClick: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(model.monitorGroups.enumerated()), id: \.element.id) { index, group in
                if index > 0 {
                    Divider()
                        .background(Color(.systemGray))
                        .frame(height: 14)
                }
                ForEach(group.workspaces) { workspace in
                    WorkspaceButton(workspace: workspace, onClick: onWorkspaceClick)
                }
            }
        }
        .padding(.horizontal, 2)
    }
}
