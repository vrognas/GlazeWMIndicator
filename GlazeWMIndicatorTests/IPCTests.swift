import Testing
import Foundation
@testable import GlazeWMIndicator

@Suite("IPC Message Decoding")
struct IPCTests {
    @Test("Decode workspaces client_response")
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

        let decoder = JSONDecoder()
        let message = try decoder.decode(ServerMessage.self, from: json)
        guard case .clientResponse(let response) = message else {
            Issue.record("Expected client_response")
            return
        }
        #expect(response.success == true)
        #expect(response.error == nil)
        guard case .workspaces(let data) = response.data else {
            Issue.record("Expected workspaces data")
            return
        }
        #expect(data.workspaces.count == 2)
        #expect(data.workspaces[0].name == "1")
        #expect(data.workspaces[0].hasFocus == true)
        #expect(data.workspaces[1].displayName == "Web")
        #expect(data.workspaces[1].parentId == "monitor-2")
        #expect(data.workspaces[0].hasWindows == true)
        #expect(data.workspaces[1].hasWindows == false)
    }

    @Test("Decode event_subscription message")
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

        let decoder = JSONDecoder()
        let message = try decoder.decode(ServerMessage.self, from: json)
        guard case .eventSubscription(let event) = message else {
            Issue.record("Expected event_subscription")
            return
        }
        #expect(event.success == true)
        #expect(event.subscriptionId == "sub-uuid-123")
    }

    @Test("Decode subscribe acknowledgment client_response")
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

        let decoder = JSONDecoder()
        let message = try decoder.decode(ServerMessage.self, from: json)
        guard case .clientResponse(let response) = message else {
            Issue.record("Expected client_response")
            return
        }
        #expect(response.success == true)
        guard case .eventSubscribe(let data) = response.data else {
            Issue.record("Expected eventSubscribe data")
            return
        }
        #expect(data.subscriptionId == "ack-uuid-456")
    }
}
