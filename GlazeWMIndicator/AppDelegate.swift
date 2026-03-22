import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    let workspaceModel = WorkspaceModel()
    let glazeClient = GlazeWMClient()
    var sinks: [AnyCancellable] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.menu = createMenu()

        let hostingView = NSHostingView(
            rootView: ContentView(onWorkspaceClick: { [weak self] name in
                self?.glazeClient.focusWorkspace(name)
            }).environmentObject(workspaceModel)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 0, height: 22)
        statusBarItem?.button?.addSubview(hostingView)
        statusBarItem?.button?.frame.size = hostingView.frame.size

        sinks.append(
            workspaceModel.$monitorGroups
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refreshBarWidth() }
        )

        glazeClient.start { [weak self] workspaces in
            Task { @MainActor in
                self?.workspaceModel.update(workspaces: workspaces)
            }
        }

        sinks.append(
            glazeClient.$isConnected.dropFirst().sink { [weak self] connected in
                DispatchQueue.main.async {
                    if connected {
                        self?.statusBarItem?.button?.title = ""
                    } else {
                        self?.showDisconnected()
                    }
                }
            }
        )
    }

    private func refreshBarWidth() {
        DispatchQueue.main.async { [weak self] in
            guard let button = self?.statusBarItem?.button,
                  let hostingView = button.subviews.first else { return }
            let fittingSize = hostingView.fittingSize
            button.title = ""
            hostingView.frame.size.width = fittingSize.width
            button.frame.size.width = fittingSize.width
            self?.statusBarItem?.length = fittingSize.width
        }
    }

    private func showDisconnected() {
        statusBarItem?.button?.title = "G"
        statusBarItem?.length = NSStatusItem.variableLength
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let aboutItem = NSMenuItem(title: "GlazeWM Indicator v\(version)", action: #selector(openRepo), keyEquivalent: "")
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/vrognas/glazewm-indicator")!)
    }

    @objc private func quit() {
        glazeClient.disconnect()
        NSApp.terminate(nil)
    }
}
