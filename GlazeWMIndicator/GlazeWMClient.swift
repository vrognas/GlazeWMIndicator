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
    private let decoder = JSONDecoder()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 1
        self.session = URLSession(configuration: config)
    }

    func start(onWorkspacesUpdate: @escaping ([WorkspaceInfo]) -> Void) {
        self.onWorkspacesUpdate = onWorkspacesUpdate
        connect()
    }

    func connect() {
        guard let url = URL(string: "ws://127.0.0.1:\(port)") else { return }
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        Task {
            let ok = await send("query workspaces")
            guard ok else { return }
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

    @discardableResult
    private func send(_ message: String) async -> Bool {
        do {
            try await webSocketTask?.send(.string(message))
            return true
        } catch {
            handleDisconnect()
            return false
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
            let message = try decoder.decode(ServerMessage.self, from: data)
            switch message {
            case .clientResponse(let response):
                if response.success, case .workspaces(let wsData) = response.data {
                    if !isConnected { isConnected = true }
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
            // Silently ignore unparseable messages
        }
    }

    private func handleDisconnect() {
        isConnected = false
        webSocketTask = nil
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if !Task.isCancelled {
                connect()
            }
        }
    }
}
