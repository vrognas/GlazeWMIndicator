# GlazeWMIndicator Design

## Context

GlazeWM is a tiling window manager for macOS and Windows. On macOS, it lacks a native menu bar integration for workspace indicators. The Zebar companion bar doesn't layer well with the native macOS menu bar. This app provides native macOS menu bar workspace indicators that communicate with GlazeWM via its IPC WebSocket.

Inspired by [YabaiIndicator](https://github.com/xiamaz/YabaiIndicator) which does the same for the Yabai window manager.

## Architecture

NSStatusItem with variable length, embedding a SwiftUI ContentView via NSHostingView. WebSocket client connects to GlazeWM IPC at ws://localhost:6123.

### Components

1. **GlazeWMClient** — WebSocket client using URLSessionWebSocketTask. Queries workspaces on connect, subscribes to workspace/focus/window events, sends focus commands on click. Auto-reconnects on disconnect (3s retry). Debounces rapid events (100ms) before re-querying.

2. **WorkspaceModel** — ObservableObject. Holds workspace state grouped by monitor (via parentId). Publishes changes to drive SwiftUI re-renders. Filters out inactive workspaces (no children).

3. **ImageGenerator** — Draws template NSImages (24x16pt rounded rects with labels). Handles arbitrary string labels (workspace names can be non-numeric), truncating if needed. Template images = auto light/dark mode adaptation. Focused = filled full opacity, displayed = filled 80% opacity, inactive = hidden.

4. **AppDelegate** — Sets up NSStatusItem, embeds SwiftUI ContentView via NSHostingView, manages lifecycle.

5. **ContentView** — SwiftUI HStack rendering workspace buttons per display with dividers between displays.

### Data Flow

```
GlazeWM IPC (ws://127.0.0.1:6123)
  -> GlazeWMClient (WebSocket, async/await)
    -> WorkspaceModel (@Published)
      -> ContentView (SwiftUI re-render)
        -> NSStatusItem width updates

Click workspace button
  -> GlazeWMClient.send("command focus --workspace N")
```

### WebSocket Protocol

**Connection:** `ws://127.0.0.1:6123` (port 6123, defined as DEFAULT_IPC_PORT)

**Response envelope** (all responses share this structure):
```json
{
  "messageType": "client_response" | "event_subscription",
  "clientMessage": "...",
  "data": { ... },
  "error": null,
  "success": true
}
```
The `messageType` field is used to dispatch: `"client_response"` for query/command replies, `"event_subscription"` for event stream messages.

**Query workspaces:**
- Send: `"query workspaces"`
- Response data: `{"workspaces": [...]}`
- Each workspace has: `name` (String), `displayName` (String?), `hasFocus` (Bool), `isDisplayed` (Bool), `parentId` (UUID, references monitor container), `children` (array, may contain nested containers — use recursive count of type "window" or simple children.count > 0 for v1)

**Subscribe to events:**
- Send: `"sub --events workspace_activated workspace_deactivated focus_changed workspace_updated window_managed window_unmanaged focused_container_moved"`
- Acknowledgment: `messageType: "client_response"` with `data: {"subscriptionId": "..."}`
- Events: `messageType: "event_subscription"` with `subscriptionId` and event data

**Send commands:**
- Send: `"command focus --workspace N"` (note: `command` prefix required)
- Response: `{"success": true}` or error

**Update strategy:** On each event, debounce 100ms, then re-query workspaces for fresh state. This avoids complex incremental state management in v1.

**JSON key strategy:** GlazeWM uses camelCase (hasFocus, isDisplayed, parentId). Swift's JSONDecoder default literal matching works directly — do NOT set `.convertFromSnakeCase`.

### Visual Design

- 24x16pt rounded rect buttons per workspace (matching YabaiIndicator)
- Display `displayName` if non-null, otherwise `name`
- Focused: filled rounded rect, inverted label, full opacity
- Displayed (visible, not focused): filled rounded rect, 80% opacity
- Inactive (no windows): hidden entirely
- Display separator: vertical divider between monitor groups
- 4px spacing between buttons
- Right-click: Quit menu item

### Error Handling

- GlazeWM not running: show dimmed "G" icon in menu bar, retry every 3s
- WebSocket disconnect: auto-reconnect, re-subscribe to events
- No active workspaces: hide status item entirely

### Not in v1 (YAGNI)

- Settings/preferences UI
- Window preview mode
- Configurable button styles
- Tiling direction / binding mode indicators
- Homebrew formula (will add after v1 works)
- Port configurability (hardcode 6123 for now)
- Unsubscribe support (not needed — connection drop handles cleanup)

## Tech Stack

- Swift 5.9+, macOS 13.0+
- AppKit (NSStatusItem, NSHostingView) + SwiftUI (ContentView)
- URLSessionWebSocketTask for WebSocket (no third-party deps)
- Xcode project
- Bundle ID: io.glzr.glazewm-indicator

## Project Structure

```
GlazeWMIndicator/
  GlazeWMIndicator.xcodeproj/
  GlazeWMIndicator/
    GlazeWMIndicatorApp.swift    -- @main entry, Settings scene
    AppDelegate.swift             -- NSStatusItem setup, lifecycle
    ContentView.swift             -- SwiftUI workspace button layout
    ImageGenerator.swift          -- Template image drawing
    GlazeWMClient.swift           -- WebSocket IPC client
    WorkspaceModel.swift          -- Observable workspace state
    Models/
      Workspace.swift             -- Workspace data model
      IPC.swift                   -- IPC message types (Codable)
  GlazeWMIndicatorTests/
    GlazeWMClientTests.swift      -- IPC message parsing tests
    WorkspaceModelTests.swift     -- State grouping and update logic tests
```
