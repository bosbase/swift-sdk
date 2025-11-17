# Realtime API - Swift SDK Documentation

## Overview

The Realtime API enables real-time updates for collection records using **Server-Sent Events (SSE)**. It allows you to subscribe to changes in collections or specific records and receive instant notifications when records are created, updated, or deleted.

**Key Features:**
- Real-time notifications for record changes
- Collection-level and record-level subscriptions
- Automatic connection management and reconnection
- Authorization support
- Subscription options (expand, custom headers, query params)
- Event-driven architecture

> 📖 **Reference**: This guide mirrors the [JavaScript SDK Realtime documentation](../js-sdk/docs/REALTIME.md) but uses Swift syntax and examples.

**Backend Endpoints:**
- `GET /api/realtime` - Establish SSE connection
- `POST /api/realtime` - Set subscriptions

## How It Works

1. **Connection**: The SDK establishes an SSE connection to `/api/realtime`
2. **Client ID**: Server sends `PB_CONNECT` event with a unique `clientId`
3. **Subscriptions**: Client submits subscription topics via POST request
4. **Events**: Server sends events when matching records change
5. **Reconnection**: SDK automatically reconnects on connection loss

## Basic Usage

### Subscribe to Collection Changes

Subscribe to all changes in a collection:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Subscribe to all changes in the 'posts' collection
let unsubscribe = try await client
    .collection("posts")
    .subscribe("*") { event in
        print("Action: \(event.action)")  // 'create', 'update', or 'delete'
        print("Record: \(event.record)")  // The record data
    }

// Later, unsubscribe
await unsubscribe()
```

### Subscribe to Specific Record

Subscribe to changes for a single record:

```swift
// Subscribe to changes for a specific post
try await client
    .collection("posts")
    .subscribe("RECORD_ID") { event in
        print("Record changed: \(event.record)")
        print("Action: \(event.action ?? "")")
    }
```

### Multiple Subscriptions

You can subscribe multiple times to the same or different topics:

```swift
// Subscribe to multiple records
let unsubscribe1 = try await client
    .collection("posts")
    .subscribe("RECORD_ID_1") { event in
        print("Change event: \(event)")
    }

let unsubscribe2 = try await client
    .collection("posts")
    .subscribe("RECORD_ID_2") { event in
        print("Change event: \(event)")
    }

let unsubscribe3 = try await client
    .collection("posts")
    .subscribe("*") { event in
        print("Collection-wide change: \(event)")
    }

// Unsubscribe individually
await unsubscribe1()
await unsubscribe2()
await unsubscribe3()
```

## Subscription Options

### With Expand

Subscribe with related records expanded:

```swift
let options = RecordSubscriptionOptions(expand: "author,comments")

let unsubscribe = try await client
    .collection("posts")
    .subscribe("RECORD_ID", options: options) { event in
        if let author = (event.record["expand"] as? [String: AnyCodable])?["author"] {
            print("Author: \(author)")
        }
    }
```

### With Filter

Subscribe only to records matching a filter:

```swift
let options = RecordSubscriptionOptions(
    filter: client.filter("status = {:status}", params: ["status": "published"])
)

let unsubscribe = try await client
    .collection("posts")
    .subscribe("*", options: options) { event in
        // Only receives events for published posts
        print("Published post changed: \(event.record)")
    }
```

### With Custom Headers

```swift
let options = RecordSubscriptionOptions(
    headers: ["X-Custom-Header": "value"]
)

let unsubscribe = try await client
    .collection("posts")
    .subscribe("*", options: options) { event in
        // Subscription with custom headers
    }
```

## Event Types

### Record Events

```swift
try await client
    .collection("posts")
    .subscribe("*") { event in
        switch event.action {
        case "create":
            print("New post created: \(event.record)")
        case "update":
            print("Post updated: \(event.record)")
        case "delete":
            print("Post deleted: \(event.record)")
        default:
            print("Unknown action: \(event.action ?? "")")
        }
    }
```

### Connection Events

The realtime service provides connection status:

```swift
// Check if connected
let clientId = await client.realtime.currentClientIdentifier()
if clientId != nil {
    print("Connected with client ID: \(clientId!)")
}

// Handle disconnection
client.realtime.onDisconnect = { activeSubscriptions in
    print("Disconnected. Active subscriptions: \(activeSubscriptions)")
}
```

## Unsubscribing

### Unsubscribe from Specific Topic

```swift
// Unsubscribe from a specific record
try await client
    .collection("posts")
    .unsubscribe("RECORD_ID")

// Unsubscribe from all collection subscriptions
try await client
    .collection("posts")
    .unsubscribe()
```

### Unsubscribe by Prefix

```swift
// Unsubscribe from all topics starting with a prefix
try await client.realtime.unsubscribeByPrefix("posts/")
```

## Complete Example

```swift
import BosBase

class PostManager {
    let client: BosBaseClient
    private var subscriptions: [() -> Void] = []
    
    init() throws {
        client = try BosBaseClient(baseURLString: "http://localhost:8090")
    }
    
    func startListening() async throws {
        // Authenticate first
        try await client
            .collection("users")
            .authWithPassword(identity: "user@example.com", password: "password123")
        
        // Subscribe to all posts
        let unsubscribeAll = try await client
            .collection("posts")
            .subscribe("*") { [weak self] event in
                self?.handlePostEvent(event)
            }
        subscriptions.append(unsubscribeAll)
        
        // Subscribe to specific post
        let unsubscribeSpecific = try await client
            .collection("posts")
            .subscribe("POST_ID") { [weak self] event in
                self?.handlePostEvent(event)
            }
        subscriptions.append(unsubscribeSpecific)
        
        // Subscribe with filter
        let options = RecordSubscriptionOptions(
            filter: client.filter("status = {:status}", params: ["status": "published"])
        )
        let unsubscribeFiltered = try await client
            .collection("posts")
            .subscribe("*", options: options) { [weak self] event in
                self?.handlePostEvent(event)
            }
        subscriptions.append(unsubscribeFiltered)
    }
    
    private func handlePostEvent(_ event: RecordSubscription<JSONRecord>) {
        switch event.action {
        case "create":
            print("New post: \(event.record["title"] ?? "")")
        case "update":
            print("Updated post: \(event.record["title"] ?? "")")
        case "delete":
            print("Deleted post: \(event.record["id"] ?? "")")
        default:
            break
        }
    }
    
    func stopListening() async {
        for unsubscribe in subscriptions {
            await unsubscribe()
        }
        subscriptions.removeAll()
    }
}

// Usage
let manager = try PostManager()
try await manager.startListening()

// Later, stop listening
await manager.stopListening()
```

## SwiftUI Integration Example

```swift
import SwiftUI
import BosBase

class RealtimeViewModel: ObservableObject {
    @Published var posts: [JSONRecord] = []
    private let client: BosBaseClient
    private var unsubscribe: (() -> Void)?
    
    init() throws {
        client = try BosBaseClient(baseURLString: "http://localhost:8090")
    }
    
    func startListening() async throws {
        // Load initial posts
        let result: ListResult<JSONRecord> = try await client
            .collection("posts")
            .getList()
        await MainActor.run {
            self.posts = result.items
        }
        
        // Subscribe to changes
        unsubscribe = try await client
            .collection("posts")
            .subscribe("*") { [weak self] event in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    switch event.action {
                    case "create":
                        self.posts.append(event.record)
                    case "update":
                        if let index = self.posts.firstIndex(where: { 
                            ($0["id"]?.value as? String) == (event.record["id"]?.value as? String)
                        }) {
                            self.posts[index] = event.record
                        }
                    case "delete":
                        self.posts.removeAll { 
                            ($0["id"]?.value as? String) == (event.record["id"]?.value as? String)
                        }
                    default:
                        break
                    }
                }
            }
    }
    
    func stopListening() async {
        await unsubscribe?()
        unsubscribe = nil
    }
}

struct PostsView: View {
    @StateObject private var viewModel: RealtimeViewModel
    
    init() throws {
        _viewModel = StateObject(wrappedValue: try RealtimeViewModel())
    }
    
    var body: some View {
        List(viewModel.posts, id: \.self) { post in
            Text(post["title"]?.value as? String ?? "")
        }
        .task {
            try? await viewModel.startListening()
        }
        .onDisappear {
            Task {
                await viewModel.stopListening()
            }
        }
    }
}
```

## Error Handling

```swift
do {
    let unsubscribe = try await client
        .collection("posts")
        .subscribe("*") { event in
            print("Event: \(event)")
        }
    
    // Store unsubscribe function for later
    // ...
    
} catch let error as ClientResponseError {
    print("Realtime error: \(error.status) - \(error.response ?? [:])")
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Authenticate First**: Always authenticate before subscribing to protected collections
2. **Unsubscribe Properly**: Always call the unsubscribe function when done to clean up resources
3. **Handle Disconnections**: Implement `onDisconnect` handler to notify users of connection issues
4. **Filter Subscriptions**: Use filters to reduce unnecessary events
5. **Memory Management**: Store unsubscribe functions and call them in `deinit` or cleanup methods
6. **Thread Safety**: Realtime callbacks may be called on background threads; use `@MainActor` for UI updates

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [Authentication](./AUTHENTICATION.md)

