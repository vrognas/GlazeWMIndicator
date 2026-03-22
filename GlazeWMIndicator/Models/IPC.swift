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
