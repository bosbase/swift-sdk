# Crons API - Swift SDK Documentation

## Overview

The Crons API provides endpoints for viewing and manually triggering scheduled cron jobs. All operations require superuser authentication and allow you to list registered cron jobs and execute them on-demand.

**Key Features:**
- List all registered cron jobs
- View cron job schedules (cron expressions)
- Manually trigger cron jobs
- Built-in system jobs for maintenance tasks

**Backend Endpoints:**
- `GET /api/crons` - List cron jobs
- `POST /api/crons/{jobId}` - Run cron job

**Note**: All Crons API operations require superuser authentication.

## Authentication

All Crons API operations require superuser authentication:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")
```

## List Cron Jobs

Returns a list of all registered cron jobs with their IDs and schedule expressions.

### Basic Usage

```swift
// Get all cron jobs
let jobs: [JSONRecord] = try await client.crons.getFullList()

for job in jobs {
    if let id = job["id"]?.value as? String,
       let expression = job["expression"]?.value as? String {
        print("\(id): \(expression)")
    }
}
```

### Cron Job Structure

Each cron job contains:

```swift
[
    "id": AnyCodable(String),        // Unique identifier for the job
    "expression": AnyCodable(String)  // Cron expression defining the schedule
]
```

### Built-in System Jobs

The following cron jobs are typically registered by default:

| Job ID | Expression | Description | Schedule |
|--------|-----------|-------------|----------|
| `__pbLogsCleanup__` | `0 */6 * * *` | Cleans up old log entries | Every 6 hours |
| `__pbDBOptimize__` | `0 0 * * *` | Optimizes database | Daily at midnight |
| `__pbMFACleanup__` | `0 * * * *` | Cleans up expired MFA records | Every hour |
| `__pbOTPCleanup__` | `0 * * * *` | Cleans up expired OTP codes | Every hour |

### Working with Cron Jobs

```swift
// List all cron jobs
let jobs: [JSONRecord] = try await client.crons.getFullList()

// Find a specific job
if let logsCleanup = jobs.first(where: { ($0["id"]?.value as? String) == "__pbLogsCleanup__" }) {
    if let expression = logsCleanup["expression"]?.value as? String {
        print("Logs cleanup runs: \(expression)")
    }
}

// Filter system jobs
let systemJobs = jobs.filter { job in
    if let id = job["id"]?.value as? String {
        return id.hasPrefix("__pb")
    }
    return false
}

// Filter custom jobs
let customJobs = jobs.filter { job in
    if let id = job["id"]?.value as? String {
        return !id.hasPrefix("__pb")
    }
    return false
}
```

## Run Cron Job

Manually trigger a cron job to execute immediately.

### Basic Usage

```swift
// Run a specific cron job
try await client.crons.run(jobId: "__pbLogsCleanup__")
```

### Use Cases

```swift
// Trigger logs cleanup manually
func cleanupLogsNow() async throws {
    try await client.crons.run(jobId: "__pbLogsCleanup__")
    print("Logs cleanup triggered")
}

// Trigger database optimization
func optimizeDatabase() async throws {
    try await client.crons.run(jobId: "__pbDBOptimize__")
    print("Database optimization triggered")
}

// Trigger MFA cleanup
func cleanupMFA() async throws {
    try await client.crons.run(jobId: "__pbMFACleanup__")
    print("MFA cleanup triggered")
}

// Trigger OTP cleanup
func cleanupOTP() async throws {
    try await client.crons.run(jobId: "__pbOTPCleanup__")
    print("OTP cleanup triggered")
}
```

## Cron Expression Format

Cron expressions use the standard 5-field format:

```
* * * * *
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, 0 or 7 is Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

### Common Patterns

| Expression | Description |
|------------|-------------|
| `0 * * * *` | Every hour at minute 0 |
| `0 */6 * * *` | Every 6 hours |
| `0 0 * * *` | Daily at midnight |
| `0 0 * * 0` | Weekly on Sunday at midnight |
| `0 0 1 * *` | Monthly on the 1st at midnight |
| `*/30 * * * *` | Every 30 minutes |
| `0 9 * * 1-5` | Weekdays at 9 AM |

### Supported Macros

| Macro | Equivalent Expression | Description |
|-------|----------------------|-------------|
| `@yearly` or `@annually` | `0 0 1 1 *` | Once a year |
| `@monthly` | `0 0 1 * *` | Once a month |
| `@weekly` | `0 0 * * 0` | Once a week |
| `@daily` or `@midnight` | `0 0 * * *` | Once a day |
| `@hourly` | `0 * * * *` | Once an hour |

### Expression Examples

```swift
// Every hour
"0 * * * *"

// Every 6 hours
"0 */6 * * *"

// Daily at midnight
"0 0 * * *"

// Every 30 minutes
"*/30 * * * *"

// Weekdays at 9 AM
"0 9 * * 1-5"

// First day of every month
"0 0 1 * *"

// Using macros
"@daily"   // Same as "0 0 * * *"
"@hourly"  // Same as "0 * * * *"
```

## Complete Examples

### Example 1: Cron Job Monitor

```swift
class CronMonitor {
    let client: BosBaseClient
    
    init(client: BosBaseClient) {
        self.client = client
    }
    
    func listAllJobs() async throws -> [JSONRecord] {
        let jobs: [JSONRecord] = try await client.crons.getFullList()
        
        print("Found \(jobs.count) cron jobs:")
        for job in jobs {
            if let id = job["id"]?.value as? String,
               let expression = job["expression"]?.value as? String {
                print("  - \(id): \(expression)")
            }
        }
        
        return jobs
    }
    
    func runJob(_ jobId: String) async throws -> Bool {
        do {
            try await client.crons.run(jobId: jobId)
            print("Successfully triggered: \(jobId)")
            return true
        } catch {
            print("Failed to run \(jobId): \(error)")
            return false
        }
    }
    
    func runMaintenanceJobs() async throws {
        let maintenanceJobs = [
            "__pbLogsCleanup__",
            "__pbDBOptimize__",
            "__pbMFACleanup__",
            "__pbOTPCleanup__"
        ]
        
        for jobId in maintenanceJobs {
            print("Running \(jobId)...")
            try await runJob(jobId)
            // Wait a bit between jobs
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
}

// Usage
let monitor = CronMonitor(client: client)
try await monitor.listAllJobs()
try await monitor.runMaintenanceJobs()
```

### Example 2: Cron Job Health Check

```swift
func checkCronJobs() async throws -> Bool {
    do {
        let jobs: [JSONRecord] = try await client.crons.getFullList()
        
        let expectedJobs = [
            "__pbLogsCleanup__",
            "__pbDBOptimize__",
            "__pbMFACleanup__",
            "__pbOTPCleanup__"
        ]
        
        let jobIds = jobs.compactMap { $0["id"]?.value as? String }
        let missingJobs = expectedJobs.filter { !jobIds.contains($0) }
        
        if !missingJobs.isEmpty {
            print("Missing expected cron jobs: \(missingJobs)")
            return false
        }
        
        print("All expected cron jobs are registered")
        return true
    } catch {
        print("Failed to check cron jobs: \(error)")
        return false
    }
}
```

### Example 3: Manual Maintenance Script

```swift
func performMaintenance() async throws {
    print("Starting maintenance tasks...")
    
    // Cleanup old logs
    print("1. Cleaning up old logs...")
    try await client.crons.run(jobId: "__pbLogsCleanup__")
    
    // Cleanup expired MFA records
    print("2. Cleaning up expired MFA records...")
    try await client.crons.run(jobId: "__pbMFACleanup__")
    
    // Cleanup expired OTP codes
    print("3. Cleaning up expired OTP codes...")
    try await client.crons.run(jobId: "__pbOTPCleanup__")
    
    // Optimize database (run last as it may take longer)
    print("4. Optimizing database...")
    try await client.crons.run(jobId: "__pbDBOptimize__")
    
    print("Maintenance tasks completed")
}
```

## Error Handling

```swift
do {
    let jobs: [JSONRecord] = try await client.crons.getFullList()
} catch let error as ClientResponseError {
    if error.status == 401 {
        print("Not authenticated")
    } else if error.status == 403 {
        print("Not a superuser")
    } else {
        print("Unexpected error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}

do {
    try await client.crons.run(jobId: "__pbLogsCleanup__")
} catch let error as ClientResponseError {
    if error.status == 401 {
        print("Not authenticated")
    } else if error.status == 403 {
        print("Not a superuser")
    } else if error.status == 404 {
        print("Cron job not found")
    } else {
        print("Unexpected error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Best Practices

1. **Check Job Existence**: Verify a cron job exists before trying to run it
2. **Error Handling**: Always handle errors when running cron jobs
3. **Rate Limiting**: Don't trigger cron jobs too frequently manually
4. **Monitoring**: Regularly check that expected cron jobs are registered
5. **Logging**: Log when cron jobs are manually triggered for auditing
6. **Testing**: Test cron jobs in development before running in production
7. **Documentation**: Document custom cron jobs and their purposes
8. **Scheduling**: Let the cron scheduler handle regular execution; use manual triggers sparingly

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Read-Only API**: The SDK API only allows listing and running jobs; adding/removing jobs must be done via backend hooks
- **Asynchronous Execution**: Running a cron job triggers it asynchronously; the API returns immediately
- **No Status**: The API doesn't provide execution status or history
- **System Jobs**: Built-in system jobs (prefixed with `__pb`) cannot be removed via the API

## Custom Cron Jobs

Custom cron jobs are typically registered through backend hooks (JavaScript VM plugins). The Crons API only allows you to:

- **View** all registered jobs (both system and custom)
- **Trigger** any registered job manually

To add or remove cron jobs, you need to use the backend hook system.

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Collection management
- [Logs API](./LOGS_API.md) - Log viewing and analysis
- [Backups API](./BACKUPS_API.md) - Backup management

