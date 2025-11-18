# Backups API - Swift SDK Documentation

## Overview

The Backups API provides endpoints for managing application data backups. You can create backups, upload existing backup files, download backups, delete backups, and restore the application from a backup.

**Key Features:**
- List all available backup files
- Create new backups with custom names or auto-generated names
- Upload existing backup ZIP files
- Download backup files (requires file token)
- Delete backup files
- Restore the application from a backup (restarts the app)

**Backend Endpoints:**
- `GET /api/backups` - List backups
- `POST /api/backups` - Create backup
- `POST /api/backups/upload` - Upload backup
- `GET /api/backups/{key}` - Download backup
- `DELETE /api/backups/{key}` - Delete backup
- `POST /api/backups/{key}/restore` - Restore backup

**Note**: All Backups API operations require superuser authentication (except download which requires a superuser file token).

## Authentication

All Backups API operations require superuser authentication:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Authenticate as superuser
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")
```

**Downloading backups** requires a superuser file token (obtained via `client.files.getToken()`), but does not require the Authorization header.

## Backup File Structure

Each backup file contains:
- `key`: The filename/key of the backup file (String)
- `size`: File size in bytes (Int)
- `modified`: ISO 8601 timestamp of when the backup was last modified (String)

```swift
struct BackupFileInfo {
    let key: String
    let size: Int
    let modified: String
}
```

## List Backups

Returns a list of all available backup files with their metadata.

### Basic Usage

```swift
// Get all backups
let backups: [JSONRecord] = try await client.backups.getFullList()

for backup in backups {
    if let key = backup["key"]?.value as? String,
       let size = backup["size"]?.value as? Int,
       let modified = backup["modified"]?.value as? String {
        print("\(key): \(size) bytes, modified: \(modified)")
    }
}
```

### Working with Backup Lists

```swift
// Sort backups by modification date (newest first)
let backups: [JSONRecord] = try await client.backups.getFullList()
let sorted = backups.sorted { backup1, backup2 in
    let date1 = (backup1["modified"]?.value as? String) ?? ""
    let date2 = (backup2["modified"]?.value as? String) ?? ""
    return date1 > date2
}

// Find the most recent backup
let mostRecent = sorted.first

// Filter backups by size (larger than 100MB)
let largeBackups = backups.filter { backup in
    if let size = backup["size"]?.value as? Int {
        return size > 100 * 1024 * 1024
    }
    return false
}

// Get total storage used by backups
let totalSize = backups.compactMap { $0["size"]?.value as? Int }.reduce(0, +)
print("Total backup storage: \(Double(totalSize) / 1024.0 / 1024.0) MB")
```

## Create Backup

Creates a new backup of the application data. The backup process is asynchronous and may take some time depending on the size of your data.

### Basic Usage

```swift
// Create backup with custom name
try await client.backups.create(name: "my_backup_2024.zip")

// Create backup with auto-generated name (pass empty string or let backend generate)
try await client.backups.create(name: "")
```

### Backup Name Format

Backup names must follow the format: `[a-z0-9_-].zip`
- Only lowercase letters, numbers, underscores, and hyphens
- Must end with `.zip`
- Maximum length: 150 characters
- Must be unique (no existing backup with the same name)

### Examples

```swift
// Create a named backup
func createNamedBackup(name: String) async throws {
    do {
        try await client.backups.create(name: name)
        print("Backup \"\(name)\" creation initiated")
    } catch let error as ClientResponseError {
        if error.status == 400 {
            print("Invalid backup name or backup already exists")
        } else {
            print("Failed to create backup: \(error)")
        }
        throw error
    }
}

// Create backup with timestamp
func createTimestampedBackup() async throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
    let timestamp = formatter.string(from: Date())
        .replacingOccurrences(of: ":", with: "-")
        .replacingOccurrences(of: ".", with: "-")
    let name = "backup_\(timestamp.prefix(19)).zip"
    try await client.backups.create(name: name)
}
```

### Important Notes

- **Asynchronous Process**: Backup creation happens in the background. The API returns immediately (204 No Content).
- **Concurrent Operations**: Only one backup or restore operation can run at a time. If another operation is in progress, you'll receive a 400 error.
- **Storage**: Backups are stored in the configured backup filesystem (local or S3).
- **S3 Consistency**: For S3 storage, the backup file may not be immediately available after creation due to eventual consistency.

## Upload Backup

Uploads an existing backup ZIP file to the server. This is useful for restoring backups created elsewhere or for importing backups.

### Basic Usage

```swift
// Upload from Data
let backupData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/backup.zip"))
let formData = MultipartFormData()
formData.append(name: "file", fileData: backupData, fileName: "backup.zip", mimeType: "application/zip")

try await client.backups.upload(formData: formData)
```

### File Requirements

- **MIME Type**: Must be `application/zip`
- **Format**: Must be a valid ZIP archive
- **Name**: Must be unique (no existing backup with the same name)
- **Validation**: The file will be validated before upload

### Examples

```swift
// Upload backup from file URL
func uploadBackupFromURL(url: URL) async throws {
    let backupData = try Data(contentsOf: url)
    let formData = MultipartFormData()
    formData.append(
        name: "file",
        fileData: backupData,
        fileName: url.lastPathComponent,
        mimeType: "application/zip"
    )
    
    try await client.backups.upload(formData: formData)
    print("Backup uploaded successfully")
}
```

## Download Backup

Downloads a backup file. Requires a superuser file token for authentication.

### Basic Usage

```swift
// Get file token
let token = try await client.files.getToken()

// Build download URL
if let url = client.backups.downloadURL(token: token, key: "pb_backup_20230519162514.zip") {
    // Download the file
    let data = try Data(contentsOf: url)
    // Save or process the data...
}
```

### Download URL Structure

The download URL format is:
```
/api/backups/{key}?token={fileToken}
```

### Examples

```swift
// Download backup function
func downloadBackup(backupKey: String) async throws -> Data? {
    do {
        // Get file token (valid for short period)
        let token = try await client.files.getToken()
        
        // Build download URL
        guard let url = client.backups.downloadURL(token: token, key: backupKey) else {
            throw NSError(domain: "BackupError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to build download URL"])
        }
        
        // Download the file
        let data = try Data(contentsOf: url)
        return data
    } catch {
        print("Failed to download backup: \(error)")
        throw error
    }
}
```

## Delete Backup

Deletes a backup file from the server.

### Basic Usage

```swift
try await client.backups.delete(key: "pb_backup_20230519162514.zip")
```

### Important Notes

- **Active Backups**: Cannot delete a backup that is currently being created or restored
- **No Undo**: Deletion is permanent
- **File System**: The file will be removed from the backup filesystem

### Examples

```swift
// Delete backup with confirmation
func deleteBackupWithConfirmation(backupKey: String) async throws {
    // In a real app, show confirmation dialog
    print("Are you sure you want to delete \(backupKey)?")
    
    do {
        try await client.backups.delete(key: backupKey)
        print("Backup deleted successfully")
    } catch let error as ClientResponseError {
        if error.status == 400 {
            print("Backup is currently in use and cannot be deleted")
        } else if error.status == 404 {
            print("Backup not found")
        } else {
            print("Failed to delete backup: \(error)")
        }
        throw error
    }
}

// Delete old backups (older than 30 days)
func deleteOldBackups() async throws {
    let backups: [JSONRecord] = try await client.backups.getFullList()
    let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
    
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    
    let oldBackups = backups.filter { backup in
        if let modified = backup["modified"]?.value as? String,
           let date = formatter.date(from: modified) {
            return date < thirtyDaysAgo
        }
        return false
    }
    
    for backup in oldBackups {
        if let key = backup["key"]?.value as? String {
            do {
                try await client.backups.delete(key: key)
                print("Deleted old backup: \(key)")
            } catch {
                print("Failed to delete \(key): \(error)")
            }
        }
    }
}
```

## Restore Backup

Restores the application from a backup file. **This operation will restart the application**.

### Basic Usage

```swift
try await client.backups.restore(key: "pb_backup_20230519162514.zip")
```

### Important Warnings

⚠️ **CRITICAL**: Restoring a backup will:
1. Replace all current application data with data from the backup
2. **Restart the application process**
3. Any unsaved changes will be lost
4. The application will be unavailable during the restore process

### Prerequisites

- **Disk Space**: Recommended to have at least **2x the backup size** in free disk space
- **UNIX Systems**: Restore is primarily supported on UNIX-based systems (Linux, macOS)
- **No Concurrent Operations**: Cannot restore if another backup or restore is in progress
- **Backup Existence**: The backup file must exist on the server

### Restore Process

The restore process performs the following steps:
1. Downloads the backup file to a temporary location
2. Extracts the backup to a temporary directory
3. Moves current `pb_data` content to a temporary location (to be deleted on next app start)
4. Moves extracted backup content to `pb_data`
5. Restarts the application

### Examples

```swift
// Restore backup with confirmation
func restoreBackupWithConfirmation(backupKey: String) async throws {
    // In a real app, show confirmation dialog
    print("⚠️ WARNING: This will replace all current data with data from \(backupKey) and restart the application.")
    print("Are you absolutely sure you want to continue?")
    
    do {
        try await client.backups.restore(key: backupKey)
        print("Restore initiated. Application will restart...")
        
        // Optionally wait and reload
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    } catch let error as ClientResponseError {
        if error.status == 400 {
            if let message = error.response?["message"]?.value as? String,
               message.contains("another backup/restore") {
                print("Another backup or restore operation is in progress")
            } else {
                print("Invalid or missing backup file")
            }
        } else {
            print("Failed to restore backup: \(error)")
        }
        throw error
    }
}
```

## Complete Examples

### Example 1: Backup Manager Class

```swift
class BackupManager {
    let client: BosBaseClient
    
    init(client: BosBaseClient) {
        self.client = client
    }
    
    func list() async throws -> [JSONRecord] {
        let backups: [JSONRecord] = try await client.backups.getFullList()
        return backups.sorted { backup1, backup2 in
            let date1 = (backup1["modified"]?.value as? String) ?? ""
            let date2 = (backup2["modified"]?.value as? String) ?? ""
            return date1 > date2
        }
    }
    
    func create(name: String? = nil) async throws -> String {
        let backupName: String
        if let name = name, !name.isEmpty {
            backupName = name
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
            let timestamp = formatter.string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: ".", with: "-")
            backupName = "backup_\(timestamp.prefix(19)).zip"
        }
        try await client.backups.create(name: backupName)
        return backupName
    }
    
    func download(key: String) async throws -> URL? {
        let token = try await client.files.getToken()
        return client.backups.downloadURL(token: token, key: key)
    }
    
    func delete(key: String) async throws {
        try await client.backups.delete(key: key)
    }
    
    func restore(key: String) async throws {
        try await client.backups.restore(key: key)
    }
    
    func cleanup(daysOld: Int = 30) async throws -> Int {
        let backups = try await list()
        let cutoff = Date().addingTimeInterval(-Double(daysOld) * 24 * 60 * 60)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let toDelete = backups.filter { backup in
            if let modified = backup["modified"]?.value as? String,
               let date = formatter.date(from: modified) {
                return date < cutoff
            }
            return false
        }
        
        for backup in toDelete {
            if let key = backup["key"]?.value as? String {
                do {
                    try await delete(key: key)
                    print("Deleted: \(key)")
                } catch {
                    print("Failed to delete \(key): \(error)")
                }
            }
        }
        
        return toDelete.count
    }
}

// Usage
let manager = BackupManager(client: client)
let backups = try await manager.list()
try await manager.create(name: "weekly_backup.zip")
```

## Error Handling

```swift
// Handle common backup errors
func handleBackupError(operation: String, key: String) async throws {
    do {
        switch operation {
        case "create":
            try await client.backups.create(name: key)
        case "delete":
            try await client.backups.delete(key: key)
        case "restore":
            try await client.backups.restore(key: key)
        default:
            break
        }
    } catch let error as ClientResponseError {
        switch error.status {
        case 400:
            if let message = error.response?["message"]?.value as? String {
                if message.contains("another backup/restore") {
                    print("Another backup or restore operation is in progress")
                } else if message.contains("already exists") {
                    print("Backup with this name already exists")
                } else {
                    print("Invalid request: \(message)")
                }
            }
        case 401:
            print("Not authenticated")
        case 403:
            print("Not a superuser")
        case 404:
            print("Backup not found")
        default:
            print("Unexpected error: \(error)")
        }
        throw error
    }
}
```

## Best Practices

1. **Regular Backups**: Create backups regularly (daily, weekly, or based on your needs)
2. **Naming Convention**: Use clear, consistent naming (e.g., `backup_YYYY-MM-DD.zip`)
3. **Backup Rotation**: Implement cleanup to remove old backups and prevent storage issues
4. **Test Restores**: Periodically test restoring backups to ensure they work
5. **Off-site Storage**: Download and store backups in a separate location
6. **Pre-Restore Backup**: Always create a backup before restoring (if possible)
7. **Monitor Storage**: Monitor backup storage usage to prevent disk space issues
8. **Documentation**: Document your backup and restore procedures
9. **Automation**: Use cron jobs or schedulers for automated backups
10. **Verification**: Verify backup integrity after creation/download

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Concurrent Operations**: Only one backup or restore can run at a time
- **Restore Restart**: Restoring a backup restarts the application
- **UNIX Systems**: Restore primarily works on UNIX-based systems
- **Disk Space**: Restore requires significant free disk space (2x backup size recommended)
- **S3 Consistency**: S3 backups may not be immediately available after creation
- **Active Backups**: Cannot delete backups that are currently being created or restored

## Related Documentation

- [File API](./FILES.md) - File handling and tokens
- [Crons API](./CRONS_API.md) - Automated backup scheduling
- [Collection API](./COLLECTION_API.md) - Collection management

