# GlazeWMIndicator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native macOS menu bar app that shows GlazeWM workspace indicators, communicating via WebSocket IPC.

**Architecture:** NSStatusItem with NSHostingView embedding SwiftUI ContentView. WebSocket client (URLSessionWebSocketTask) connects to GlazeWM at ws://localhost:6123, queries workspaces, subscribes to events, sends focus commands on click.

**Tech Stack:** Swift 5.9+, macOS 13.0+, AppKit (NSStatusItem, NSHostingView), SwiftUI, URLSessionWebSocketTask, XCTest

**Design doc:** `docs/plans/2026-03-22-glazewm-indicator-design.md`

---

### Task 1: Scaffold Xcode project and git repo

**Files:**
- Create: Xcode project at `/Users/vrognas/git_repos/GlazeWMIndicator/`

**Step 1: Initialize git repo**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git init
```

**Step 2: Create Xcode project via command line**

Create a Swift Package-based app or use `xcodegen` / manual project creation. Since we need an NSStatusItem (AppKit), we need a proper macOS app target.

Create the project structure manually:

```bash
mkdir -p GlazeWMIndicator
mkdir -p GlazeWMIndicatorTests
```

**Step 3: Create Package.swift**

Use Swift Package Manager for a macOS executable target. This avoids needing Xcode project files for now and keeps things buildable from CLI.

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlazeWMIndicator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GlazeWMIndicator",
            path: "GlazeWMIndicator"
        ),
        .testTarget(
            name: "GlazeWMIndicatorTests",
            dependencies: ["GlazeWMIndicator"],
            path: "GlazeWMIndicatorTests"
        ),
    ]
)
```

**Step 4: Create minimal app entry point**

Create `GlazeWMIndicator/GlazeWMIndicatorApp.swift`:

```swift
import SwiftUI

@main
struct GlazeWMIndicatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

Create `GlazeWMIndicator/AppDelegate.swift`:

```swift
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.button?.title = "G"
    }
}
```

**Step 5: Create .gitignore**

```
.DS_Store
.build/
.swiftpm/
*.xcodeproj
xcuserdata/
DerivedData/
```

**Step 6: Build and verify**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift build`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add -A
git commit -m "feat: scaffold GlazeWMIndicator project with minimal app entry point"
```

---

### Task 2: IPC message types (Codable models)

**Files:**
- Create: `GlazeWMIndicator/Models/IPC.swift`
- Create: `GlazeWMIndicator/Models/Workspace.swift`
- Create: `GlazeWMIndicatorTests/IPCTests.swift`

**Step 1: Write the failing test**

Create `GlazeWMIndicatorTests/IPCTests.swift`:

```swift
import XCTest
@testable import GlazeWMIndicator

final class IPCTests: XCTestCase {
    func testDecodeWorkspacesResponse() throws {
        let json = """
        {
            "messageType": "client_response",
            "clientMessage": "query workspaces",
            "data": {
                "workspaces": [
                    {
                        "type": "workspace",
                        "id": "abc-123",
                        "name": "1",
                        "displayName": null,
                        "hasFocus": true,
                        "isDisplayed": true,
                        "parentId": "monitor-1",
                        "children": [
                            {"type": "window", "id": "win-1"}
                        ]
                    },
                    {
                        "type": "workspace",
                        "id": "abc-456",
                        "name": "2",
                        "displayName": "Web",
                        "hasFocus": false,
                        "isDisplayed": true,
                        "parentId": "monitor-2",
                        "children": []
                    }
                ]
            },
            "error": null,
            "success": true
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(ServerMessage.self, from: json)
        guard case .clientResponse(let response) = message else {
            XCTFail("Expected client_response")
            return
        }
        XCTAssertTrue(response.success)
        XCTAssertNil(response.error)
        guard case .workspaces(let data) = response.data else {
            XCTFail("Expected workspaces data")
            return
        }
        XCTAssertEqual(data.workspaces.count, 2)
        XCTAssertEqual(data.workspaces[0].name, "1")
        XCTAssertTrue(data.workspaces[0].hasFocus)
        XCTAssertEqual(data.workspaces[1].displayName, "Web")
        XCTAssertEqual(data.workspaces[1].parentId, "monitor-2")
        XCTAssertTrue(data.workspaces[0].hasWindows)
        XCTAssertFalse(data.workspaces[1].hasWindows)
    }

    func testDecodeEventSubscription() throws {
        let json = """
        {
            "messageType": "event_subscription",
            "subscriptionId": "sub-uuid-123",
            "data": {"type": "workspace_activated"},
            "error": null,
            "success": true
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(ServerMessage.self, from: json)
        guard case .eventSubscription(let event) = message else {
            XCTFail("Expected event_subscription")
            return
        }
        XCTAssertTrue(event.success)
        XCTAssertEqual(event.subscriptionId, "sub-uuid-123")
    }

    func testDecodeSubscribeAcknowledgment() throws {
        let json = """
        {
            "messageType": "client_response",
            "clientMessage": "sub --events workspace_activated",
            "data": {"subscriptionId": "ack-uuid-456"},
            "error": null,
            "success": true
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(ServerMessage.self, from: json)
        guard case .clientResponse(let response) = message else {
            XCTFail("Expected client_response")
            return
        }
        XCTAssertTrue(response.success)
        guard case .eventSubscribe(let data) = response.data else {
            XCTFail("Expected eventSubscribe data")
            return
        }
        XCTAssertEqual(data.subscriptionId, "ack-uuid-456")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift test 2>&1 | tail -20`
Expected: FAIL — ServerMessage type not found

**Step 3: Implement IPC models**

Create `GlazeWMIndicator/Models/IPC.swift`:

```swift
import Foundation

enum ServerMessage: Decodable {
    case clientResponse(ClientResponseMessage)
    case eventSubscription(EventSubscriptionMessage)

    private enum CodingKeys: String, CodingKey {
        case messageType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .messageType)
        switch type {
        case "client_response":
            self = .clientResponse(try ClientResponseMessage(from: decoder))
        case "event_subscription":
            self = .eventSubscription(try EventSubscriptionMessage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .messageType, in: container,
                debugDescription: "Unknown messageType: \(type)"
            )
        }
    }
}

struct ClientResponseMessage: Decodable {
    let clientMessage: String
    let data: ClientResponseData?
    let error: String?
    let success: Bool
}

enum ClientResponseData: Decodable {
    case workspaces(WorkspacesData)
    case eventSubscribe(EventSubscribeData)
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let workspaces = try? container.decode(WorkspacesData.self) {
            self = .workspaces(workspaces)
            return
        }
        if let subscribe = try? container.decode(EventSubscribeData.self) {
            self = .eventSubscribe(subscribe)
            return
        }
        self = .other
    }
}

struct WorkspacesData: Decodable {
    let workspaces: [WorkspaceInfo]
}

struct EventSubscribeData: Decodable {
    let subscriptionId: String
}

struct EventSubscriptionMessage: Decodable {
    let subscriptionId: String
    let data: EventData?
    let error: String?
    let success: Bool
}

struct EventData: Decodable {
    let type: String
}
```

Create `GlazeWMIndicator/Models/Workspace.swift`:

```swift
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
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift test 2>&1 | tail -20`
Expected: All 3 tests PASS

**Step 5: Commit**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git add -A
git commit -m "feat: add IPC message types with Codable decoding"
```

---

### Task 3: WebSocket client (GlazeWMClient)

**Files:**
- Create: `GlazeWMIndicator/GlazeWMClient.swift`

**Step 1: Implement the WebSocket client**

Create `GlazeWMIndicator/GlazeWMClient.swift`:

```swift
import Foundation

@MainActor
class GlazeWMClient: ObservableObject {
    @Published var isConnected = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private let port: Int = 6123
    private var onWorkspacesUpdate: (([WorkspaceInfo]) -> Void)?
    private var reconnectTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    init() {
        self.session = URLSession(configuration: .default)
    }

    func start(onWorkspacesUpdate: @escaping ([WorkspaceInfo]) -> Void) {
        self.onWorkspacesUpdate = onWorkspacesUpdate
        connect()
    }

    func connect() {
        guard let url = URL(string: "ws://127.0.0.1:\(port)") else { return }
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        Task {
            await queryWorkspaces()
            await subscribeToEvents()
            await receiveMessages()
        }
    }

    func disconnect() {
        reconnectTask?.cancel()
        debounceTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    func focusWorkspace(_ name: String) {
        Task {
            await send("command focus --workspace \(name)")
        }
    }

    // MARK: - Private

    private func send(_ message: String) async {
        do {
            try await webSocketTask?.send(.string(message))
        } catch {
            handleDisconnect()
        }
    }

    private func queryWorkspaces() async {
        await send("query workspaces")
    }

    private func subscribeToEvents() async {
        await send("sub --events workspace_activated workspace_deactivated focus_changed workspace_updated window_managed window_unmanaged focused_container_moved")
    }

    private func receiveMessages() async {
        guard let task = webSocketTask else { return }
        do {
            while true {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }
            }
        } catch {
            handleDisconnect()
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            let message = try JSONDecoder().decode(ServerMessage.self, from: data)
            switch message {
            case .clientResponse(let response):
                if response.success, case .workspaces(let wsData) = response.data {
                    onWorkspacesUpdate?(wsData.workspaces)
                }
            case .eventSubscription:
                // Debounce: wait 100ms then re-query
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if !Task.isCancelled {
                        await queryWorkspaces()
                    }
                }
            }
        } catch {
            // Ignore unparseable messages
        }
    }

    private func handleDisconnect() {
        isConnected = false
        webSocketTask = nil
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                connect()
            }
        }
    }
}
```

**Step 2: Build to verify compilation**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git add GlazeWMIndicator/GlazeWMClient.swift
git commit -m "feat: add WebSocket client for GlazeWM IPC"
```

---

### Task 4: WorkspaceModel (observable state grouped by monitor)

**Files:**
- Create: `GlazeWMIndicator/WorkspaceModel.swift`
- Create: `GlazeWMIndicatorTests/WorkspaceModelTests.swift`

**Step 1: Write the failing test**

Create `GlazeWMIndicatorTests/WorkspaceModelTests.swift`:

```swift
import XCTest
@testable import GlazeWMIndicator

final class WorkspaceModelTests: XCTestCase {
    func testGroupsByMonitor() {
        let workspaces = [
            WorkspaceInfo(type: "workspace", id: "1", name: "1", displayName: nil, hasFocus: true, isDisplayed: true, parentId: "mon-1", children: [ChildContainer(type: "window", id: "w1")]),
            WorkspaceInfo(type: "workspace", id: "2", name: "2", displayName: nil, hasFocus: false, isDisplayed: true, parentId: "mon-2", children: [ChildContainer(type: "window", id: "w2")]),
            WorkspaceInfo(type: "workspace", id: "3", name: "3", displayName: nil, hasFocus: false, isDisplayed: false, parentId: "mon-1", children: [ChildContainer(type: "window", id: "w3")]),
        ]

        let model = WorkspaceModel()
        model.update(workspaces: workspaces)

        XCTAssertEqual(model.monitorGroups.count, 2)
        // Monitor 1 has 2 active workspaces (ws 1 and ws 3 both have windows)
        XCTAssertEqual(model.monitorGroups[0].workspaces.count, 2)
        // Monitor 2 has 1 active workspace
        XCTAssertEqual(model.monitorGroups[1].workspaces.count, 1)
    }

    func testFiltersInactiveWorkspaces() {
        let workspaces = [
            WorkspaceInfo(type: "workspace", id: "1", name: "1", displayName: nil, hasFocus: true, isDisplayed: true, parentId: "mon-1", children: [ChildContainer(type: "window", id: "w1")]),
            WorkspaceInfo(type: "workspace", id: "2", name: "2", displayName: nil, hasFocus: false, isDisplayed: false, parentId: "mon-1", children: []),
        ]

        let model = WorkspaceModel()
        model.update(workspaces: workspaces)

        // Only 1 workspace shown (ws 2 has no windows and is not displayed)
        XCTAssertEqual(model.monitorGroups[0].workspaces.count, 1)
    }

    func testDisplayedWorkspaceWithoutWindowsIsShown() {
        let workspaces = [
            WorkspaceInfo(type: "workspace", id: "1", name: "1", displayName: nil, hasFocus: true, isDisplayed: true, parentId: "mon-1", children: []),
        ]

        let model = WorkspaceModel()
        model.update(workspaces: workspaces)

        // Workspace is displayed (visible on monitor) even though it has no windows
        XCTAssertEqual(model.monitorGroups[0].workspaces.count, 1)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift test 2>&1 | tail -20`
Expected: FAIL — WorkspaceModel not found

**Step 3: Implement WorkspaceModel**

Create `GlazeWMIndicator/WorkspaceModel.swift`:

```swift
import Foundation

struct MonitorGroup: Identifiable {
    let id: String // parentId (monitor ID)
    let workspaces: [WorkspaceInfo]
}

@MainActor
class WorkspaceModel: ObservableObject {
    @Published var monitorGroups: [MonitorGroup] = []

    func update(workspaces: [WorkspaceInfo]) {
        // Filter: show workspace if it has windows OR is displayed on a monitor
        let active = workspaces.filter { $0.hasWindows || $0.isDisplayed }

        // Group by parentId (monitor), preserving order of first appearance
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
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift test 2>&1 | tail -20`
Expected: All tests PASS

**Step 5: Commit**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git add -A
git commit -m "feat: add WorkspaceModel with monitor grouping and filtering"
```

---

### Task 5: ImageGenerator (template images for workspace buttons)

**Files:**
- Create: `GlazeWMIndicator/ImageGenerator.swift`

**Step 1: Implement ImageGenerator**

Create `GlazeWMIndicator/ImageGenerator.swift`:

```swift
import Cocoa

func generateWorkspaceImage(label: String, active: Bool, visible: Bool) -> NSImage {
    let size = CGSize(width: 24, height: 16)
    let cornerRadius: CGFloat = 4
    let canvas = NSRect(origin: .zero, size: size)
    let image = NSImage(size: size)
    let strokeColor = NSColor.black

    if active || visible {
        let imageFill = NSImage(size: size)
        let imageText = NSImage(size: size)

        imageFill.lockFocus()
        strokeColor.setFill()
        NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        imageFill.unlockFocus()

        imageText.lockFocus()
        drawLabel(label as NSString, color: strokeColor, size: size)
        imageText.unlockFocus()

        image.lockFocus()
        imageFill.draw(in: canvas, from: .zero, operation: .sourceOut, fraction: active ? 1.0 : 0.8)
        imageText.draw(in: canvas, from: .zero, operation: .destinationOut, fraction: active ? 1.0 : 0.8)
        image.unlockFocus()
    } else {
        image.lockFocus()
        strokeColor.setStroke()
        let path = NSBezierPath(
            roundedRect: canvas.insetBy(dx: 0.5, dy: 0.5),
            xRadius: cornerRadius, yRadius: cornerRadius
        )
        path.stroke()
        drawLabel(label as NSString, color: strokeColor, size: size)
        image.unlockFocus()
    }

    image.isTemplate = true
    return image
}

private func drawLabel(_ text: NSString, color: NSColor, size: CGSize) {
    let fontSize: CGFloat = 10
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
        .foregroundColor: color,
    ]
    let boundingBox = text.size(withAttributes: attrs)
    let x = size.width / 2 - boundingBox.width / 2
    let y = size.height / 2 - boundingBox.height / 2
    text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}
```

**Step 2: Build to verify compilation**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git add GlazeWMIndicator/ImageGenerator.swift
git commit -m "feat: add template image generator for workspace buttons"
```

---

### Task 6: ContentView (SwiftUI workspace buttons)

**Files:**
- Create: `GlazeWMIndicator/ContentView.swift`

**Step 1: Implement ContentView**

Create `GlazeWMIndicator/ContentView.swift`:

```swift
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
```

**Step 2: Build to verify compilation**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git add GlazeWMIndicator/ContentView.swift
git commit -m "feat: add SwiftUI ContentView with workspace buttons"
```

---

### Task 7: Wire up AppDelegate (connect everything)

**Files:**
- Modify: `GlazeWMIndicator/AppDelegate.swift`

**Step 1: Update AppDelegate to wire all components**

Replace `GlazeWMIndicator/AppDelegate.swift` with:

```swift
import SwiftUI
import Combine

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

        // Update status bar width when model changes
        sinks.append(
            workspaceModel.objectWillChange.sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.refreshBarWidth()
                }
            }
        )

        // Start WebSocket client
        glazeClient.start { [weak self] workspaces in
            Task { @MainActor in
                self?.workspaceModel.update(workspaces: workspaces)
            }
        }

        // Show disconnected state
        sinks.append(
            glazeClient.$isConnected.sink { [weak self] connected in
                DispatchQueue.main.async {
                    if !connected {
                        self?.showDisconnected()
                    }
                }
            }
        )
    }

    private func refreshBarWidth() {
        guard let button = statusBarItem?.button,
              let hostingView = button.subviews.first else { return }
        let fittingSize = hostingView.fittingSize
        hostingView.frame.size.width = fittingSize.width
        button.frame.size.width = fittingSize.width
        statusBarItem?.length = fittingSize.width
    }

    private func showDisconnected() {
        statusBarItem?.button?.title = "G"
        statusBarItem?.length = NSStatusItem.variableLength
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit GlazeWMIndicator", action: #selector(quit), keyEquivalent: "q")
        return menu
    }

    @objc private func quit() {
        glazeClient.disconnect()
        NSApp.terminate(nil)
    }
}
```

**Step 2: Build to verify compilation**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git add GlazeWMIndicator/AppDelegate.swift
git commit -m "feat: wire up AppDelegate with status bar, model, and WebSocket client"
```

---

### Task 8: Integration test with live GlazeWM

**Step 1: Run the app**

Run: `cd /Users/vrognas/git_repos/GlazeWMIndicator && swift run`

**Step 2: Verify checklist**

- [ ] App appears in menu bar with workspace indicators
- [ ] Only active workspaces shown (ones with windows or currently displayed)
- [ ] Focused workspace has filled button
- [ ] Display separator visible between monitor groups
- [ ] Clicking a workspace button switches to that workspace
- [ ] Switching workspaces via keyboard (alt+1-9) updates the indicators
- [ ] Opening/closing windows updates which workspaces are shown
- [ ] Right-click shows Quit menu
- [ ] If GlazeWM is killed, indicator shows "G" and reconnects when GlazeWM restarts

**Step 3: Fix any issues found during testing**

**Step 4: Final commit**

```bash
cd /Users/vrognas/git_repos/GlazeWMIndicator
git add -A
git commit -m "feat: GlazeWMIndicator v0.1.0 - working menu bar workspace indicator"
```

---

### Task 9: Disable Zebar on primary monitor (optional cleanup)

Once the menu bar indicator works, the Zebar primary monitor widget is redundant.

**Files:**
- Modify: `/Users/vrognas/.glzr/zebar/settings.json` — remove the `with-glazewm-primary` startup config

**Step 1: Update settings.json**

Keep only the secondary monitor Zebar widget (which still serves a purpose if it has dockToEdge for gap management). Or remove Zebar entirely if the indicator covers both monitors.

This is a user decision — present options during testing.
