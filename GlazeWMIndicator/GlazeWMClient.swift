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
