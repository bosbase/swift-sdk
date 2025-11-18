# Logs API - Swift SDK Documentation

## Overview

The Logs API provides endpoints for viewing and analyzing application logs. All operations require superuser authentication and allow you to query request logs, filter by various criteria, and get aggregated statistics.

**Key Features:**
- List and paginate logs
- View individual log entries
- Filter logs by status, URL, method, IP, etc.
- Sort logs by various fields
- Get hourly aggregated statistics
- Filter statistics by criteria

**Backend Endpoints:**
- `GET /api/logs` - List logs
- `GET /api/logs/{id}` - View log
- `GET /api/logs/stats` - Get statistics

**Note**: All Logs API operations require superuser authentication.

## Authentication

All Logs API operations require superuser authentication:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")
```

## List Logs

Returns a paginated list of logs with support for filtering and sorting.

### Basic Usage

```swift
// Basic list
let result: JSONRecord = try await client.logs.getList(page: 1, perPage: 30)

if let page = result["page"]?.value as? Int,
   let perPage = result["perPage"]?.value as? Int,
   let totalItems = result["totalItems"]?.value as? Int,
   let items = result["items"]?.value as? [JSONRecord] {
    print("Page: \(page)")
    print("Per Page: \(perPage)")
    print("Total Items: \(totalItems)")
    print("Items: \(items.count)")
}
```

### Log Entry Structure

Each log entry contains:

```swift
[
    "id": AnyCodable("ai5z3aoed6809au"),
    "created": AnyCodable("2024-10-27 09:28:19.524Z"),
    "level": AnyCodable(0),
    "message": AnyCodable("GET /api/collections/posts/records"),
    "data": AnyCodable([
        "auth": AnyCodable("_superusers"),
        "execTime": AnyCodable(2.392327),
        "method": AnyCodable("GET"),
        "referer": AnyCodable("http://localhost:8090/_/"),
        "remoteIP": AnyCodable("127.0.0.1"),
        "status": AnyCodable(200),
        "type": AnyCodable("request"),
        "url": AnyCodable("/api/collections/posts/records?page=1"),
        "userAgent": AnyCodable("Mozilla/5.0..."),
        "userIP": AnyCodable("127.0.0.1")
    ])
]
```

### Filtering Logs

```swift
// Filter by HTTP status code
let errorLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.status >= 400"
)

// Filter by method
let getLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.method = \"GET\""
)

// Filter by URL pattern
let apiLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.url ~ \"/api/\""
)

// Filter by IP address
let ipLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.remoteIP = \"127.0.0.1\""
)

// Filter by execution time (slow requests)
let slowLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.execTime > 1.0"
)

// Filter by log level
let errorLevelLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "level > 0"
)

// Filter by date range
let recentLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "created >= \"2024-10-27 00:00:00\""
)
```

### Complex Filters

```swift
// Multiple conditions
let complexFilter: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.status >= 400 && data.method = \"POST\" && data.execTime > 0.5"
)

// Exclude superuser requests
let userLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.auth != \"_superusers\""
)

// Specific endpoint errors
let endpointErrors: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.url ~ \"/api/collections/posts/records\" && data.status >= 400"
)

// Errors or slow requests
let problems: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "data.status >= 400 || data.execTime > 2.0"
)
```

### Sorting Logs

```swift
// Sort by creation date (newest first)
let recent: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    sort: "-created"
)

// Sort by execution time (slowest first)
let slowest: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    sort: "-data.execTime"
)

// Sort by status code
let byStatus: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    sort: "data.status"
)

// Sort by rowid (most efficient)
let byRowId: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    sort: "-rowid"
)

// Multiple sort fields
let multiSort: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    sort: "-created,level"
)
```

## View Log

Retrieve a single log entry by ID:

```swift
// Get specific log
let log: JSONRecord = try await client.logs.getOne("ai5z3aoed6809au")

if let message = log["message"]?.value as? String,
   let data = log["data"]?.value as? JSONRecord,
   let status = data["status"]?.value as? Int,
   let execTime = data["execTime"]?.value as? Double {
    print("Message: \(message)")
    print("Status: \(status)")
    print("Execution Time: \(execTime)")
}
```

### Log Details

```swift
func analyzeLog(_ logId: String) async throws {
    let log: JSONRecord = try await client.logs.getOne(logId)
    
    print("Log ID: \(log["id"]?.value ?? "")")
    print("Created: \(log["created"]?.value ?? "")")
    print("Level: \(log["level"]?.value ?? 0)")
    print("Message: \(log["message"]?.value ?? "")")
    
    if let data = log["data"]?.value as? JSONRecord,
       let type = data["type"]?.value as? String,
       type == "request" {
        print("Method: \(data["method"]?.value ?? "")")
        print("URL: \(data["url"]?.value ?? "")")
        print("Status: \(data["status"]?.value ?? 0)")
        print("Execution Time: \(data["execTime"]?.value ?? 0.0) ms")
        print("Remote IP: \(data["remoteIP"]?.value ?? "")")
        print("User Agent: \(data["userAgent"]?.value ?? "")")
        print("Auth Collection: \(data["auth"]?.value ?? "")")
    }
}
```

## Logs Statistics

Get hourly aggregated statistics for logs:

### Basic Usage

```swift
// Get all statistics
let stats: [JSONRecord] = try await client.logs.getStats()

// Each stat entry contains:
// { total: 4, date: "2022-06-01 19:00:00.000" }
for stat in stats {
    if let total = stat["total"]?.value as? Int,
       let date = stat["date"]?.value as? String {
        print("\(date): \(total) requests")
    }
}
```

### Filtered Statistics

```swift
// Statistics for errors only
let errorStats: [JSONRecord] = try await client.logs.getStats(
    query: ["filter": "data.status >= 400"]
)

// Statistics for specific endpoint
let endpointStats: [JSONRecord] = try await client.logs.getStats(
    query: ["filter": "data.url ~ \"/api/collections/posts/records\""]
)

// Statistics for slow requests
let slowStats: [JSONRecord] = try await client.logs.getStats(
    query: ["filter": "data.execTime > 1.0"]
)

// Statistics excluding superuser requests
let userStats: [JSONRecord] = try await client.logs.getStats(
    query: ["filter": "data.auth != \"_superusers\""]
)
```

## Filter Syntax

Logs support filtering with a flexible syntax similar to records filtering.

### Supported Fields

**Direct Fields:**
- `id` - Log ID
- `created` - Creation timestamp
- `updated` - Update timestamp
- `level` - Log level (0 = info, higher = warnings/errors)
- `message` - Log message

**Data Fields (nested):**
- `data.status` - HTTP status code
- `data.method` - HTTP method (GET, POST, etc.)
- `data.url` - Request URL
- `data.execTime` - Execution time in seconds
- `data.remoteIP` - Remote IP address
- `data.userIP` - User IP address
- `data.userAgent` - User agent string
- `data.referer` - Referer header
- `data.auth` - Auth collection ID
- `data.type` - Log type (usually "request")

### Filter Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Equal | `data.status = 200` |
| `!=` | Not equal | `data.status != 200` |
| `>` | Greater than | `data.status > 400` |
| `>=` | Greater than or equal | `data.status >= 400` |
| `<` | Less than | `data.execTime < 0.5` |
| `<=` | Less than or equal | `data.execTime <= 1.0` |
| `~` | Contains/Like | `data.url ~ "/api/"` |
| `!~` | Not contains | `data.url !~ "/admin/"` |

### Logical Operators

- `&&` - AND
- `||` - OR
- `()` - Grouping

### Filter Examples

```swift
// Simple equality
filter: "data.method = \"GET\""

// Range filter
filter: "data.status >= 400 && data.status < 500"

// Pattern matching
filter: "data.url ~ \"/api/collections/\""

// Complex logic
filter: "(data.status >= 400 || data.execTime > 2.0) && data.method = \"POST\""

// Exclude patterns
filter: "data.url !~ \"/admin/\" && data.auth != \"_superusers\""

// Date range
filter: "created >= \"2024-10-27 00:00:00\" && created <= \"2024-10-28 00:00:00\""
```

## Sort Options

Supported sort fields:

- `@random` - Random order
- `rowid` - Row ID (most efficient, use negative for DESC)
- `id` - Log ID
- `created` - Creation date
- `updated` - Update date
- `level` - Log level
- `message` - Message text
- `data.*` - Any data field (e.g., `data.status`, `data.execTime`)

```swift
// Sort examples
sort: "-created"              // Newest first
sort: "data.execTime"         // Fastest first
sort: "-data.execTime"        // Slowest first
sort: "-rowid"                // Most efficient (newest)
sort: "level,-created"        // By level, then newest
```

## Complete Examples

### Example 1: Error Monitoring Dashboard

```swift
func getErrorMetrics() async throws -> [String: Any] {
    // Get error logs from last 24 hours
    let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let dateFilter = "created >= \"\(formatter.string(from: yesterday))\""
    
    // 4xx errors
    let clientErrors: JSONRecord = try await client.logs.getList(
        page: 1,
        perPage: 100,
        filter: "\(dateFilter) && data.status >= 400 && data.status < 500",
        sort: "-created"
    )
    
    // 5xx errors
    let serverErrors: JSONRecord = try await client.logs.getList(
        page: 1,
        perPage: 100,
        filter: "\(dateFilter) && data.status >= 500",
        sort: "-created"
    )
    
    // Get hourly statistics
    let errorStats: [JSONRecord] = try await client.logs.getStats(
        query: ["filter": "\(dateFilter) && data.status >= 400"]
    )
    
    return [
        "clientErrors": clientErrors["items"]?.value ?? [],
        "serverErrors": serverErrors["items"]?.value ?? [],
        "stats": errorStats
    ]
}
```

### Example 2: Performance Analysis

```swift
func analyzePerformance() async throws -> [String: [String: Double]] {
    // Get slow requests
    let slowRequests: JSONRecord = try await client.logs.getList(
        page: 1,
        perPage: 50,
        filter: "data.execTime > 1.0",
        sort: "-data.execTime"
    )
    
    // Analyze by endpoint
    var endpointStats: [String: [String: Double]] = [:]
    
    if let items = slowRequests["items"]?.value as? [JSONRecord] {
        for log in items {
            if let data = log["data"]?.value as? JSONRecord,
               let url = data["url"]?.value as? String,
               let execTime = data["execTime"]?.value as? Double {
                let endpoint = url.components(separatedBy: "?").first ?? url
                
                if endpointStats[endpoint] == nil {
                    endpointStats[endpoint] = [
                        "count": 0,
                        "totalTime": 0,
                        "maxTime": 0
                    ]
                }
                
                endpointStats[endpoint]?["count"] = (endpointStats[endpoint]?["count"] ?? 0) + 1
                endpointStats[endpoint]?["totalTime"] = (endpointStats[endpoint]?["totalTime"] ?? 0) + execTime
                endpointStats[endpoint]?["maxTime"] = max(endpointStats[endpoint]?["maxTime"] ?? 0, execTime)
            }
        }
    }
    
    // Calculate averages
    for (endpoint, stats) in endpointStats {
        if let count = stats["count"], let totalTime = stats["totalTime"], count > 0 {
            endpointStats[endpoint]?["avgTime"] = totalTime / count
        }
    }
    
    return endpointStats
}
```

## Error Handling

```swift
do {
    let logs: JSONRecord = try await client.logs.getList(
        page: 1,
        perPage: 50,
        filter: "data.status >= 400"
    )
} catch let error as ClientResponseError {
    if error.status == 401 {
        print("Not authenticated")
    } else if error.status == 403 {
        print("Not a superuser")
    } else if error.status == 400 {
        print("Invalid filter: \(error.response ?? [:])")
    } else {
        print("Unexpected error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Use Filters**: Always use filters to narrow down results, especially for large log datasets
2. **Paginate**: Use pagination instead of fetching all logs at once
3. **Efficient Sorting**: Use `-rowid` for default sorting (most efficient)
4. **Filter Statistics**: Always filter statistics for meaningful insights
5. **Monitor Errors**: Regularly check for 4xx/5xx errors
6. **Performance Tracking**: Monitor execution times for slow endpoints
7. **Security Auditing**: Track authentication failures and suspicious activity
8. **Archive Old Logs**: Consider deleting or archiving old logs to maintain performance

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Data Fields**: Only fields in the `data` object are filterable
- **Statistics**: Statistics are aggregated hourly
- **Performance**: Large log datasets may be slow to query
- **Storage**: Logs accumulate over time and may need periodic cleanup

## Log Levels

- **0**: Info (normal requests)
- **> 0**: Warnings/Errors (non-200 status codes, exceptions, etc.)

Higher values typically indicate more severe issues.

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - User authentication
- [API Records](./API_RECORDS.md) - Record operations
- [Collection API](./COLLECTION_API.md) - Collection management

