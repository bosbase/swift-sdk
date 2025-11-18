# Cache API - Swift SDK Documentation

## Overview

BosBase caches combine in-memory [FreeCache](https://github.com/coocood/freecache) storage with persistent database copies. Each cache instance is safe to use in single-node or multi-node (cluster) mode: nodes read from FreeCache first, fall back to the database if an item is missing or expired, and then reload FreeCache automatically.

The Swift SDK exposes the cache endpoints through `client.caches`. Typical use cases include:

- Caching AI prompts/responses that must survive restarts.
- Quickly sharing feature flags and configuration between workers.
- Preloading expensive vector search results for short periods.

> **Timeouts & TTLs:** Each cache defines a default TTL (in seconds). Individual entries may provide their own `ttlSeconds`. A value of `0` keeps the entry until it is manually deleted.

## List available caches

The `list()` function allows you to query and retrieve all currently available caches, including their names and capacities. This is particularly useful for AI systems to discover existing caches before creating new ones, avoiding duplicate cache creation.

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
try await client
    .collection("_superusers")
    .authWithPassword(identity: "root@example.com", password: "hunter2")

// Query all available caches
let caches: [JSONRecord] = try await client.caches.list()

// Each cache object contains:
// - name: String - The cache identifier
// - sizeBytes: Int - The cache capacity in bytes
// - defaultTTLSeconds: Int - Default expiration time
// - readTimeoutMs: Int - Read timeout in milliseconds
// - created: String - Creation timestamp (RFC3339)
// - updated: String - Last update timestamp (RFC3339)

// Example: Find a cache by name and check its capacity
if let targetCache = caches.first(where: { ($0["name"]?.value as? String) == "ai-session" }) {
    if let sizeBytes = targetCache["sizeBytes"]?.value as? Int {
        print("Cache \"ai-session\" has capacity of \(sizeBytes) bytes")
        // Use the existing cache directly
    }
} else {
    print("Cache not found, create a new one if needed")
}
```

## Manage cache configurations

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
try await client
    .collection("_superusers")
    .authWithPassword(identity: "root@example.com", password: "hunter2")

// List all available caches (including name and capacity).
// This is useful for AI to discover existing caches before creating new ones.
let caches: [JSONRecord] = try await client.caches.list()
print("Available caches: \(caches)")

// Find an existing cache by name
if let existingCache = caches.first(where: { ($0["name"]?.value as? String) == "ai-session" }) {
    if let sizeBytes = existingCache["sizeBytes"]?.value as? Int {
        print("Found cache \"ai-session\" with capacity \(sizeBytes) bytes")
        // Use the existing cache directly without creating a new one
    }
} else {
    // Create a new cache only if it doesn't exist
    _ = try await client.caches.create(
        name: "ai-session",
        sizeBytes: 64 * 1024 * 1024,
        defaultTTLSeconds: 300,
        readTimeoutMs: 25  // optional concurrency guard
    )
}

// Update limits later (eg. shrink TTL to 2 minutes).
_ = try await client.caches.update(
    name: "ai-session",
    body: [
        "defaultTTLSeconds": AnyCodable(120)
    ]
)

// Delete the cache (DB rows + FreeCache).
try await client.caches.delete(name: "ai-session")
```

Field reference:

| Field | Description |
|-------|-------------|
| `sizeBytes` | Approximate FreeCache size. Values too small (<512KB) or too large (>512MB) are clamped. |
| `defaultTTLSeconds` | Default expiration for entries. `0` means no expiration. |
| `readTimeoutMs` | Optional lock timeout while reading FreeCache. When exceeded, the value is fetched from the database instead. |

## Work with cache entries

```swift
// Store an object in cache. The same payload is serialized into the DB.
_ = try await client.caches.setEntry(
    cache: "ai-session",
    key: "dialog:42",
    value: AnyCodable([
        "prompt": AnyCodable("describe Saturn"),
        "embedding": AnyCodable([/* vector */])
    ]),
    ttlSeconds: 90  // per-entry TTL in seconds
)

// Read from cache. `source` indicates where the hit came from.
let entry: JSONRecord = try await client.caches.getEntry(
    cache: "ai-session",
    key: "dialog:42"
)

print(entry["source"] ?? "")   // "cache" or "database"
print(entry["expiresAt"] ?? "") // RFC3339 timestamp or undefined

// Renew an entry's TTL without changing its value.
// This extends the expiration time by the specified TTL (or uses the cache's default TTL if omitted).
let renewed: JSONRecord = try await client.caches.renewEntry(
    cache: "ai-session",
    key: "dialog:42",
    ttlSeconds: 120  // extend by 120 seconds
)
print(renewed["expiresAt"] ?? "") // new expiration time

// Delete an entry.
try await client.caches.deleteEntry(
    cache: "ai-session",
    key: "dialog:42"
)
```

### Cluster-aware behaviour

1. **Write-through persistence** – every `setEntry` writes to FreeCache and the `_cache_entries` table so other nodes (or a restarted node) can immediately reload values.
2. **Read path** – FreeCache is consulted first. If a lock cannot be acquired within `readTimeoutMs` or if the entry is missing/expired, BosBase queries the database copy and repopulates FreeCache in the background.
3. **Automatic cleanup** – expired entries are ignored and removed from the database when fetched, preventing stale data across nodes.

Use caches whenever you need fast, transient data that must still be recoverable or shareable across BosBase nodes.

## Complete Examples

### Example 1: Feature Flag Cache

```swift
class FeatureFlagCache {
    let client: BosBaseClient
    let cacheName = "feature-flags"
    
    init(client: BosBaseClient) {
        self.client = client
    }
    
    func setup() async throws {
        // Check if cache exists
        let caches: [JSONRecord] = try await client.caches.list()
        let exists = caches.contains { ($0["name"]?.value as? String) == cacheName }
        
        if !exists {
            // Create cache with 1 hour default TTL
            _ = try await client.caches.create(
                name: cacheName,
                sizeBytes: 1024 * 1024,  // 1MB
                defaultTTLSeconds: 3600
            )
        }
    }
    
    func getFlag(_ flagName: String) async throws -> Bool? {
        let entry: JSONRecord = try await client.caches.getEntry(
            cache: cacheName,
            key: flagName
        )
        
        return entry["value"]?.value as? Bool
    }
    
    func setFlag(_ flagName: String, value: Bool) async throws {
        _ = try await client.caches.setEntry(
            cache: cacheName,
            key: flagName,
            value: AnyCodable(value),
            ttlSeconds: 3600  // 1 hour
        )
    }
}

// Usage
let flagCache = FeatureFlagCache(client: client)
try await flagCache.setup()
try await flagCache.setFlag("new-feature", value: true)
let enabled = try await flagCache.getFlag("new-feature")
```

### Example 2: AI Response Cache

```swift
class AIResponseCache {
    let client: BosBaseClient
    let cacheName = "ai-responses"
    
    init(client: BosBaseClient) {
        self.client = client
    }
    
    func setup() async throws {
        let caches: [JSONRecord] = try await client.caches.list()
        let exists = caches.contains { ($0["name"]?.value as? String) == cacheName }
        
        if !exists {
            _ = try await client.caches.create(
                name: cacheName,
                sizeBytes: 64 * 1024 * 1024,  // 64MB
                defaultTTLSeconds: 1800  // 30 minutes
            )
        }
    }
    
    func getCachedResponse(prompt: String) async throws -> String? {
        let key = prompt.sha256()  // Use hash as key
        
        let entry: JSONRecord = try await client.caches.getEntry(
            cache: cacheName,
            key: key
        )
        
        return entry["value"]?.value as? String
    }
    
    func cacheResponse(prompt: String, response: String) async throws {
        let key = prompt.sha256()
        
        _ = try await client.caches.setEntry(
            cache: cacheName,
            key: key,
            value: AnyCodable(response),
            ttlSeconds: 1800
        )
    }
}

// Usage
let aiCache = AIResponseCache(client: client)
try await aiCache.setup()

// Check cache first
if let cached = try await aiCache.getCachedResponse(prompt: "What is AI?") {
    print("Cached response: \(cached)")
} else {
    // Generate response and cache it
    let response = "AI is..."
    try await aiCache.cacheResponse(prompt: "What is AI?", response: response)
}
```

## Error Handling

```swift
do {
    let entry: JSONRecord = try await client.caches.getEntry(
        cache: "my-cache",
        key: "my-key"
    )
} catch let error as ClientResponseError {
    if error.status == 404 {
        print("Cache or entry not found")
    } else if error.status == 400 {
        print("Invalid request: \(error.response ?? [:])")
    } else {
        print("Unexpected error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Check Before Create**: Always check if a cache exists before creating it
2. **Appropriate TTLs**: Set TTLs based on your data freshness requirements
3. **Size Limits**: Don't create caches larger than needed (clamped to 512MB max)
4. **Key Naming**: Use consistent, descriptive key naming conventions
5. **Error Handling**: Always handle cache misses and errors gracefully
6. **Cluster Awareness**: Remember that caches are shared across nodes in cluster mode

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection management
- [API Records](./API_RECORDS.md) - Record operations

