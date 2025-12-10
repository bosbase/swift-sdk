# Plugins Proxy API - Swift SDK

The `plugins` helper forwards requests through `/api/plugins/{...}` to your configured plugin service (`PLUGIN_URL`). It supports standard HTTP verbs plus SSE and WebSocket helpers, and will include your auth token automatically when present.

## HTTP requests

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// GET /api/plugins/health
let health: JSONRecord = try await client.plugins.request(.get, path: "health")

// POST with JSON body and headers
let created: JSONRecord = try await client.plugins.request(
    .post,
    path: "tasks",
    body: .encodable(["title": AnyCodable("Generate docs")]),
    headers: ["X-Plugin-Key": "demo-secret"]
)

// Query parameters and other verbs (PATCH/DELETE/HEAD/OPTIONS)
let summary: JSONRecord = try await client.plugins.request(
    .get,
    path: "reports/summary",
    query: ["since": "2024-01-01", "limit": 50]
)
```

Paths are normalized automatically: leading slashes are trimmed and missing `/api/plugins/` is prefixed for you.

## Server-Sent Events (SSE)

```swift
let stream = try client.plugins.openEventStream(
    path: "events/updates",
    query: ["topic": "team-alpha"]
) { event in
    // event.event, event.data, event.id
    if let data = event.data {
        print("update:", data)
    }
} onError: { error in
    print("stream error:", error)
}

// Close when done
stream.close()
```

When an auth token exists it is added as `?token=...` because SSE clients cannot reliably set custom headers across platforms. Provided headers are still forwarded when supported.

## WebSockets

```swift
let socket = try client.plugins.openWebSocket(
    path: "ws/chat",
    query: ["room": "general"],
    headers: ["X-Plugin-Key": "secret"],
    protocols: ["json"] // optional subprotocols
)

Task {
    while true {
        let message = try await socket.receive()
        switch message {
        case .string(let text):
            print("message:", text)
        case .data(let data):
            print("binary message:", data)
        @unknown default:
            break
        }
    }
}

socket.send(.string("{\"type\":\"join\",\"name\":\"lea\"}")) { error in
    if let error { print("send failed:", error) }
}
```

The SDK rewrites your base URL to `ws://` or `wss://`, preserves query params, and appends the auth token as `token` when available. Custom headers are passed to `URLSessionWebSocketTask` (browsers ignore non-standard headers).

## Behavior
- HTTP calls honor `beforeSend`/`afterSend` hooks and all `RequestOptions`.
- SSE and WebSocket helpers skip those hooks and stream directly via URLSession.
- The plugin proxy endpoints are public by default—enforce any plugin-side checks you need (tokens, IP allowlists, etc.).
