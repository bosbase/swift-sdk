# Health API - Swift SDK Documentation

## Overview

The Health API provides a simple endpoint to check the health status of the server. It returns basic health information and, when authenticated as a superuser, provides additional diagnostic information about the server state.

**Key Features:**
- No authentication required for basic health check
- Superuser authentication provides additional diagnostic data
- Lightweight endpoint for monitoring and health checks
- Supports both GET and HEAD methods

**Backend Endpoints:**
- `GET /api/health` - Check health status
- `HEAD /api/health` - Check health status (HEAD method)

**Note**: The health endpoint is publicly accessible, but superuser authentication provides additional information.

## Authentication

Basic health checks do not require authentication:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Basic health check (no auth required)
let health: JSONRecord = try await client.health.check()
```

For additional diagnostic information, authenticate as a superuser:

```swift
// Authenticate as superuser for extended health data
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

let health: JSONRecord = try await client.health.check()
```

## Health Check Response Structure

### Basic Response (Guest/Regular User)

```swift
[
    "code": AnyCodable(200),
    "message": AnyCodable("API is healthy."),
    "data": AnyCodable([:])
]
```

### Superuser Response

```swift
[
    "code": AnyCodable(200),
    "message": AnyCodable("API is healthy."),
    "data": AnyCodable([
        "canBackup": AnyCodable(true),           // Whether backup operations are allowed
        "realIP": AnyCodable("192.168.1.100"),   // Real IP address of the client
        "requireS3": AnyCodable(false),          // Whether S3 storage is required
        "possibleProxyHeader": AnyCodable("")    // Detected proxy header (if behind reverse proxy)
    ])
]
```

## Check Health Status

Returns the health status of the API server.

### Basic Usage

```swift
// Simple health check
let health: JSONRecord = try await client.health.check()

print(health["message"] ?? "") // "API is healthy."
print(health["code"] ?? 0)     // 200
```

### With Superuser Authentication

```swift
// Authenticate as superuser first
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Get extended health information
let health: JSONRecord = try await client.health.check()

if let data = health["data"]?.value as? JSONRecord {
    print(data["canBackup"] ?? false)           // true/false
    print(data["realIP"] ?? "")                  // "192.168.1.100"
    print(data["requireS3"] ?? false)            // false
    print(data["possibleProxyHeader"] ?? "")     // "" or header name
}
```

## Response Fields

### Common Fields (All Users)

| Field | Type | Description |
|-------|------|-------------|
| `code` | Int | HTTP status code (always 200 for healthy server) |
| `message` | String | Health status message ("API is healthy.") |
| `data` | Dictionary | Health data (empty for non-superusers, populated for superusers) |

### Superuser-Only Fields (in `data`)

| Field | Type | Description |
|-------|------|-------------|
| `canBackup` | Bool | `true` if backup/restore operations can be performed, `false` if a backup/restore is currently in progress |
| `realIP` | String | The real IP address of the client (useful when behind proxies) |
| `requireS3` | Bool | `true` if S3 storage is required (local fallback disabled), `false` otherwise |
| `possibleProxyHeader` | String | Detected proxy header name (e.g., "X-Forwarded-For", "CF-Connecting-IP") if the server appears to be behind a reverse proxy, empty string otherwise |

## Use Cases

### 1. Basic Health Monitoring

```swift
func checkServerHealth() async throws -> Bool {
    do {
        let health: JSONRecord = try await client.health.check()
        
        if let code = health["code"]?.value as? Int,
           code == 200,
           let message = health["message"]?.value as? String,
           message == "API is healthy." {
            print("✓ Server is healthy")
            return true
        } else {
            print("✗ Server health check failed")
            return false
        }
    } catch {
        print("✗ Health check error: \(error)")
        return false
    }
}

// Use in monitoring
Task {
    while true {
        let isHealthy = try? await checkServerHealth()
        if isHealthy == false {
            print("Server health check failed!")
        }
        try? await Task.sleep(nanoseconds: 60_000_000_000) // Check every minute
    }
}
```

### 2. Backup Readiness Check

```swift
func canPerformBackup() async throws -> Bool {
    // Authenticate as superuser
    try await client
        .collection("_superusers")
        .authWithPassword(identity: "admin@example.com", password: "password")
    
    let health: JSONRecord = try await client.health.check()
    
    if let data = health["data"]?.value as? JSONRecord,
       let canBackup = data["canBackup"]?.value as? Bool,
       canBackup == false {
        print("⚠️ Backup operation is currently in progress")
        return false
    }
    
    print("✓ Backup operations are allowed")
    return true
}

// Use before creating backups
if try await canPerformBackup() {
    try await client.backups.create(name: "backup.zip")
}
```

### 3. Monitoring Dashboard

```swift
class HealthMonitor {
    let client: BosBaseClient
    var isSuperuser = false
    
    init(client: BosBaseClient) {
        self.client = client
    }
    
    func authenticateAsSuperuser(email: String, password: String) async throws -> Bool {
        do {
            try await client
                .collection("_superusers")
                .authWithPassword(identity: email, password: password)
            isSuperuser = true
            return true
        } catch {
            print("Superuser authentication failed: \(error)")
            return false
        }
    }
    
    func getHealthStatus() async throws -> [String: Any] {
        do {
            let health: JSONRecord = try await client.health.check()
            
            var status: [String: Any] = [
                "healthy": (health["code"]?.value as? Int) == 200,
                "message": health["message"]?.value as? String ?? "",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
            
            if isSuperuser, let data = health["data"]?.value as? JSONRecord {
                status["diagnostics"] = [
                    "canBackup": data["canBackup"]?.value ?? nil,
                    "realIP": data["realIP"]?.value ?? nil,
                    "requireS3": data["requireS3"]?.value ?? nil,
                    "behindProxy": (data["possibleProxyHeader"]?.value as? String) != nil,
                    "proxyHeader": data["possibleProxyHeader"]?.value ?? nil
                ]
            }
            
            return status
        } catch {
            return [
                "healthy": false,
                "error": "\(error)",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        }
    }
}

// Usage
let monitor = HealthMonitor(client: client)
try await monitor.authenticateAsSuperuser(email: "admin@example.com", password: "password")
let status = try await monitor.getHealthStatus()
print("Health Status: \(status)")
```

### 4. Load Balancer Health Check

```swift
// Simple health check for load balancers
func simpleHealthCheck() async throws -> Bool {
    do {
        let health: JSONRecord = try await client.health.check()
        return (health["code"]?.value as? Int) == 200
    } catch {
        return false
    }
}

// Use in server route for load balancer
let isHealthy = try? await simpleHealthCheck()
if isHealthy == true {
    // Return 200 OK
} else {
    // Return 503 Service Unavailable
}
```

### 5. Proxy Detection

```swift
func checkProxySetup() async throws -> [String: Any?] {
    try await client
        .collection("_superusers")
        .authWithPassword(identity: "admin@example.com", password: "password")
    
    let health: JSONRecord = try await client.health.check()
    let data = health["data"]?.value as? JSONRecord
    let proxyHeader = data?["possibleProxyHeader"]?.value as? String
    
    if let proxyHeader = proxyHeader, !proxyHeader.isEmpty {
        print("⚠️ Server appears to be behind a reverse proxy")
        print("   Detected proxy header: \(proxyHeader)")
        print("   Real IP: \(data?["realIP"]?.value ?? "")")
        
        // Provide guidance on trusted proxy configuration
        print("   Ensure TrustedProxy settings are configured correctly in admin panel")
    } else {
        print("✓ No reverse proxy detected (or properly configured)")
    }
    
    return [
        "behindProxy": proxyHeader != nil && !proxyHeader!.isEmpty,
        "proxyHeader": proxyHeader,
        "realIP": data?["realIP"]?.value
    ]
}
```

## Error Handling

```swift
func safeHealthCheck() async throws -> [String: Any] {
    do {
        let health: JSONRecord = try await client.health.check()
        return [
            "success": true,
            "data": health
        ]
    } catch {
        // Network errors, server down, etc.
        return [
            "success": false,
            "error": "\(error)",
            "code": (error as? ClientResponseError)?.status ?? 0
        ]
    }
}

// Handle different error scenarios
let result = try await safeHealthCheck()
if let success = result["success"] as? Bool, !success {
    if let code = result["code"] as? Int, code == 0 {
        print("Network error or server unreachable")
    } else {
        print("Server returned error: \(result["code"] ?? 0)")
    }
}
```

## Best Practices

1. **Monitoring**: Use health checks for regular monitoring (e.g., every 30-60 seconds)
2. **Load Balancers**: Configure load balancers to use the health endpoint for health checks
3. **Pre-flight Checks**: Check `canBackup` before initiating backup operations
4. **Error Handling**: Always handle errors gracefully as the server may be down
5. **Rate Limiting**: Don't poll the health endpoint too frequently (avoid spamming)
6. **Caching**: Consider caching health check results for a few seconds to reduce load
7. **Logging**: Log health check results for troubleshooting and monitoring
8. **Alerting**: Set up alerts for consecutive health check failures
9. **Superuser Auth**: Only authenticate as superuser when you need diagnostic information
10. **Proxy Configuration**: Use `possibleProxyHeader` to detect and configure reverse proxy settings

## Response Codes

| Code | Meaning |
|------|---------|
| 200 | Server is healthy |
| Network Error | Server is unreachable or down |

## Limitations

- **No Detailed Metrics**: The health endpoint does not provide detailed performance metrics
- **Basic Status Only**: Returns basic status, not detailed system information
- **Superuser Required**: Extended diagnostics require superuser authentication
- **No Historical Data**: Only returns current status, no historical health data

## Related Documentation

- [Backups API](./BACKUPS_API.md) - Using `canBackup` to check backup readiness
- [Authentication](./AUTHENTICATION.md) - Superuser authentication
- [Settings API](./MANAGEMENT_API.md) - Configuring trusted proxy settings

