# Management API - Swift SDK Documentation

This document covers the management API capabilities available in the Swift SDK, which correspond to the features available in the backend management UI.

> **Note**: All management API operations require superuser authentication (🔐).

## Table of Contents

- [Settings Service](#settings-service)
  - [Application Configuration](#application-configuration)
  - [Mail Configuration](#mail-configuration)
  - [Storage Configuration](#storage-configuration)
- [Backup Service](#backup-service)
- [Log Service](#log-service)
- [Cron Service](#cron-service)
- [Health Service](#health-service)
- [Collection Service](#collection-service)

---

## Settings Service

The Settings Service provides comprehensive management of application settings, matching the capabilities available in the backend management UI.

### Application Configuration

Manage application settings including meta information, trusted proxy, rate limits, and batch configuration.

#### Get Application Settings

```swift
let settings: JSONRecord = try await client.settings.getAll()
// Returns all settings including: meta, trustedProxy, rateLimits, batch

if let meta = settings["meta"]?.value as? JSONRecord {
    print(meta["appName"]?.value as? String ?? "")
}
```

**Example:**
```swift
let appSettings: JSONRecord = try await client.settings.getApplicationSettings()
if let meta = appSettings["meta"]?.value as? JSONRecord {
    print("App Name: \(meta["appName"]?.value as? String ?? "")")
}
```

#### Update Application Settings

```swift
_ = try await client.settings.updateApplicationSettings(
    meta: [
        "appName": AnyCodable("My App"),
        "appURL": AnyCodable("https://example.com"),
        "hideControls": AnyCodable(false)
    ],
    trustedProxy: [
        "headers": AnyCodable(["X-Forwarded-For"]),
        "useLeftmostIP": AnyCodable(true)
    ],
    rateLimits: [
        "enabled": AnyCodable(true),
        "rules": AnyCodable([
            [
                "label": AnyCodable("api/users"),
                "duration": AnyCodable(3600),
                "maxRequests": AnyCodable(100)
            ]
        ])
    ],
    batch: [
        "enabled": AnyCodable(true),
        "maxRequests": AnyCodable(100),
        "interval": AnyCodable(200)
    ]
)
```

#### Individual Settings Updates

**Update Meta Settings:**
```swift
_ = try await client.settings.updateMeta(
    appName: "My App",
    appURL: "https://example.com",
    senderName: "My App",
    senderAddress: "noreply@example.com",
    hideControls: false
)
```

**Update All Settings:**
```swift
_ = try await client.settings.update(body: [
    "meta": AnyCodable([
        "appName": AnyCodable("My App"),
        "appURL": AnyCodable("https://example.com")
    ]),
    "trustedProxy": AnyCodable([
        "headers": AnyCodable(["X-Forwarded-For", "X-Real-IP"]),
        "useLeftmostIP": AnyCodable(true)
    ])
])
```

---

### Mail Configuration

Manage SMTP email settings and sender information.

#### Get Mail Settings

```swift
let settings: JSONRecord = try await client.settings.getAll()
if let meta = settings["meta"]?.value as? JSONRecord {
    print("Sender Name: \(meta["senderName"]?.value as? String ?? "")")
    print("Sender Address: \(meta["senderAddress"]?.value as? String ?? "")")
}
```

#### Update Mail Settings

Update both sender info and SMTP configuration:

```swift
_ = try await client.settings.update(body: [
    "meta": AnyCodable([
        "senderName": AnyCodable("My App"),
        "senderAddress": AnyCodable("noreply@example.com")
    ]),
    "smtp": AnyCodable([
        "enabled": AnyCodable(true),
        "host": AnyCodable("smtp.example.com"),
        "port": AnyCodable(587),
        "username": AnyCodable("user@example.com"),
        "password": AnyCodable("password"),
        "authMethod": AnyCodable("PLAIN"),
        "tls": AnyCodable(true),
        "localName": AnyCodable("localhost")
    ])
])
```

#### Test Email

Send a test email to verify SMTP configuration:

```swift
try await client.settings.testEmail(
    toEmail: "test@example.com",
    template: "verification", // template: verification, password-reset, email-change, otp, login-alert
    collection: "_superusers" // optional, defaults to _superusers
)
```

**Email Templates:**
- `verification` - Email verification template
- `password-reset` - Password reset template
- `email-change` - Email change confirmation template
- `otp` - One-time password template
- `login-alert` - Login alert template

---

### Storage Configuration

Manage S3 storage configuration for file storage.

#### Get Storage S3 Configuration

```swift
let settings: JSONRecord = try await client.settings.getAll()
if let s3 = settings["s3"]?.value as? JSONRecord {
    print("S3 Enabled: \(s3["enabled"]?.value as? Bool ?? false)")
    print("S3 Bucket: \(s3["bucket"]?.value as? String ?? "")")
}
```

#### Update Storage S3 Configuration

```swift
_ = try await client.settings.update(body: [
    "s3": AnyCodable([
        "enabled": AnyCodable(true),
        "bucket": AnyCodable("my-bucket"),
        "region": AnyCodable("us-east-1"),
        "endpoint": AnyCodable("https://s3.amazonaws.com"),
        "accessKey": AnyCodable("ACCESS_KEY"),
        "secret": AnyCodable("SECRET_KEY"),
        "forcePathStyle": AnyCodable(false)
    ])
])
```

#### Test Storage S3 Connection

```swift
try await client.settings.testS3(filesystem: "storage")
// Returns successfully if connection succeeds
```

---

## Backup Service

Manage application backups - create, list, upload, delete, and restore backups.

### List All Backups

```swift
let backups: [JSONRecord] = try await client.backups.getFullList()
// Returns: Array<{ key, size, modified }>

for backup in backups {
    if let key = backup["key"]?.value as? String,
       let size = backup["size"]?.value as? Int,
       let modified = backup["modified"]?.value as? String {
        print("\(key): \(size) bytes, modified: \(modified)")
    }
}
```

### Create Backup

```swift
try await client.backups.create(name: "backup-2024-01-01")
// Creates a new backup with the specified basename
```

### Upload Backup

Upload an existing backup file:

```swift
let backupData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/backup.zip"))
let formData = MultipartFormData()
formData.append(name: "file", fileData: backupData, fileName: "backup.zip", mimeType: "application/zip")

try await client.backups.upload(formData: formData)
```

### Delete Backup

```swift
try await client.backups.delete(key: "backup-2024-01-01")
// Deletes the specified backup file
```

### Restore Backup

```swift
try await client.backups.restore(key: "backup-2024-01-01")
// Restores the application from the specified backup
```

**⚠️ Warning**: Restoring a backup will replace all current application data!

### Get Backup Download URL

```swift
// First, get a file token
let token = try await client.files.getToken()

// Then build the download URL
if let url = client.backups.downloadURL(token: token, key: "backup-2024-01-01") {
    print("Download URL: \(url)")
}
```

---

## Log Service

Query and analyze application logs.

### List Logs

```swift
let result: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 30,
    filter: "level >= 0",
    sort: "-created"
)
// Returns: { page, perPage, totalItems, totalPages, items }

if let items = result["items"]?.value as? [JSONRecord] {
    for log in items {
        print("Log: \(log)")
    }
}
```

**Example with filtering:**
```swift
// Get error logs from the last 24 hours
let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]

let errorLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 50,
    filter: "level > 0 && created >= \"\(formatter.string(from: yesterday))\"",
    sort: "-created"
)

if let items = errorLogs["items"]?.value as? [JSONRecord] {
    for log in items {
        if let message = log["message"]?.value as? String {
            print("[\(log["level"]?.value ?? 0)] \(message)")
        }
    }
}
```

### Get Single Log

```swift
let log: JSONRecord = try await client.logs.getOne("log-id")
// Returns: LogModel with full log details
```

### Get Log Statistics

```swift
let stats: [JSONRecord] = try await client.logs.getStats(
    query: ["filter": "level >= 0"] // Optional filter
)
// Returns: Array<{ total, date }> - hourly statistics

for stat in stats {
    if let total = stat["total"]?.value as? Int,
       let date = stat["date"]?.value as? String {
        print("\(date): \(total) requests")
    }
}
```

---

## Cron Service

Manage and execute cron jobs.

### List All Cron Jobs

```swift
let cronJobs: [JSONRecord] = try await client.crons.getFullList()
// Returns: Array<{ id, expression }>

for job in cronJobs {
    if let id = job["id"]?.value as? String,
       let expression = job["expression"]?.value as? String {
        print("Job \(id): \(expression)")
    }
}
```

### Run Cron Job

Manually trigger a cron job:

```swift
try await client.crons.run(jobId: "job-id")
// Executes the specified cron job immediately
```

**Example:**
```swift
let cronJobs: [JSONRecord] = try await client.crons.getFullList()
if let backupJob = cronJobs.first(where: { ($0["id"]?.value as? String)?.contains("backup") ?? false }) {
    if let jobId = backupJob["id"]?.value as? String {
        try await client.crons.run(jobId: jobId)
        print("Backup job executed manually")
    }
}
```

---

## Health Service

Check the health status of the API.

### Check Health

```swift
let health: JSONRecord = try await client.health.check()
// Returns: Health status information

if let code = health["code"]?.value as? Int,
   code == 200 {
    print("API is healthy: \(health)")
}
```

---

## Collection Service

Manage collections (schemas) programmatically.

### List Collections

```swift
let collections: ListResult<JSONRecord> = try await client.collections.getList(page: 1, perPage: 30)
// Returns: Paginated list of collections
```

### Get Collection

```swift
let collection: JSONRecord = try await client.collections.getOne("collection-id-or-name")
// Returns: Full collection schema
```

### Create Collection

```swift
let collection: JSONRecord = try await client.collections.create(body: [
    "name": AnyCodable("posts"),
    "type": AnyCodable("base"),
    "fields": AnyCodable([
        [
            "name": AnyCodable("title"),
            "type": AnyCodable("text"),
            "required": AnyCodable(true)
        ],
        [
            "name": AnyCodable("content"),
            "type": AnyCodable("editor"),
            "required": AnyCodable(false)
        ]
    ])
])
```

### Update Collection

```swift
_ = try await client.collections.update("collection-id", body: [
    "fields": AnyCodable([
        // Updated schema
    ])
])
```

### Delete Collection

```swift
try await client.collections.delete("collection-id")
```

### Truncate Collection

Delete all records in a collection (keeps the schema):

```swift
try await client.collections.truncate("collection-id")
```

### Import Collections

```swift
let collections: [JSONRecord] = [
    [
        "name": AnyCodable("collection1"),
        // ... collection schema
    ],
    [
        "name": AnyCodable("collection2"),
        // ... collection schema
    ]
]

_ = try await client.collections.importCollections(collections)
```

---

## Complete Example: Automated Backup Management

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Check current backup settings
let settings: JSONRecord = try await client.settings.getAll()
if let backups = settings["backups"]?.value as? JSONRecord {
    print("Current backup schedule: \(backups["cron"]?.value ?? "")")
}

// List all existing backups
let backups: [JSONRecord] = try await client.backups.getFullList()
print("Found \(backups.count) backups")

// Create a new backup
try await client.backups.create(name: "manual-backup-\(Date().description)")
print("Backup created successfully")

// Get updated backup list
let updatedBackups: [JSONRecord] = try await client.backups.getFullList()
print("Now have \(updatedBackups.count) backups")
```

---

## Complete Example: Log Monitoring

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Get recent error logs
let errorLogs: JSONRecord = try await client.logs.getList(
    page: 1,
    perPage: 20,
    filter: "level > 0",
    sort: "-created"
)

if let totalItems = errorLogs["totalItems"]?.value as? Int {
    print("Found \(totalItems) error logs")
}

if let items = errorLogs["items"]?.value as? [JSONRecord] {
    for log in items {
        if let message = log["message"]?.value as? String,
           let level = log["level"]?.value as? Int,
           let created = log["created"]?.value as? String {
            print("[\(level)] \(message) - \(created)")
        }
    }
}

// Get hourly statistics for the last 24 hours
let yesterday = Date().addingTimeInterval(-24 * 60 * 60)
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]

let stats: [JSONRecord] = try await client.logs.getStats(
    query: ["filter": "created >= \"\(formatter.string(from: yesterday))\""]
)

print("Hourly request statistics:")
for stat in stats {
    if let total = stat["total"]?.value as? Int,
       let date = stat["date"]?.value as? String {
        print("\(date): \(total) requests")
    }
}
```

---

## Error Handling

All management API methods can throw `ClientResponseError`. Always handle errors appropriately:

```swift
do {
    try await client.backups.create(name: "my-backup")
    print("Backup created successfully")
} catch let error as ClientResponseError {
    if error.status == 401 {
        print("Authentication required")
    } else if error.status == 403 {
        print("Superuser access required")
    } else {
        print("Error: \(error.response ?? [:])")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

---

## Notes

1. **Authentication**: All management API operations require superuser authentication. Use `client.collection("_superusers").authWithPassword()` to authenticate.

2. **Rate Limiting**: Be mindful of rate limits when making multiple management API calls.

3. **Backup Safety**: Always test backup restoration in a safe environment before using in production.

4. **Log Retention**: Setting appropriate log retention helps manage storage usage.

5. **Cron Jobs**: Manual cron execution is useful for testing but should be used carefully in production.

For more information on specific services, see:
- [Backups API](./BACKUPS_API.md) - Detailed backup operations
- [Logs API](./LOGS_API.md) - Detailed log operations
- [Collections API](./COLLECTION_API.md) - Collection management
- [Crons API](./CRONS_API.md) - Cron job management
- [Health API](./HEALTH_API.md) - Health check operations

