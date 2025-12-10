# Redis API (Swift SDK)

Redis helpers are available when the server is started with `REDIS_URL` (and optional `REDIS_PASSWORD`). Endpoints are superuser-only.

## Discover keys

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
try await client.collection("_superusers").authWithPassword(identity: "root@example.com", password: "hunter2")

let page = try await client.redis.listKeys(pattern: "session:*", count: 100)
print(page.cursor)        // pass back into listKeys to continue scanning
print(page.items.map(\.key))
```

## Create, read, update, delete keys

```swift
// Create a key only if it doesn't already exist
let created = try await client.redis.createKey(
    "session:123",
    value: ["prompt": "hello", "tokens": 42],
    ttlSeconds: 3600
)
print(created.ttlSeconds ?? 0)

// Read the value back with current TTL (nil when persistent)
let entry = try await client.redis.getKey("session:123")
print(entry.value, entry.ttlSeconds as Any)

// Update an existing key (preserves TTL when ttlSeconds is omitted)
let updated = try await client.redis.updateKey(
    "session:123",
    value: ["prompt": "updated", "tokens": 99],
    ttlSeconds: 120   // set 2-minute TTL; use 0 to remove TTL
)
print(updated.ttlSeconds ?? 0)

// Delete
try await client.redis.deleteKey("session:123")
```

Responses:
- `listKeys` returns `RedisListPage { cursor: String, items: [RedisKeySummary] }`.
- `createKey`, `getKey`, and `updateKey` return `RedisEntry { key, value, ttlSeconds? }`.
- `createKey` fails with HTTP 409 if the key already exists.
