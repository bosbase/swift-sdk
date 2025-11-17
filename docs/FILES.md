# Files Upload and Handling - Swift SDK Documentation

## Overview

BosBase allows you to upload and manage files through file fields in your collections. Files are stored with sanitized names and a random suffix for security (e.g., `test_52iwbgds7l.png`).

**Key Features:**
- Upload multiple files per field
- Maximum file size: ~8GB (2^53-1 bytes)
- Automatic filename sanitization and random suffix
- Image thumbnails support
- Protected files with token-based access
- File modifiers for append/prepend/delete operations

> 📖 **Reference**: This guide mirrors the [JavaScript SDK Files documentation](../js-sdk/docs/FILES.md) but uses Swift syntax and examples.

**Backend Endpoints:**
- `POST /api/files/token` - Get file access token for protected files
- `GET /api/files/{collection}/{recordId}/{filename}` - Download file

## File Field Configuration

Before uploading files, you must add a file field to your collection:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Get collection
var collection: JSONRecord = try await client.collections.getOne("example")

// Add file field
var fields = collection["fields"] as? [[String: AnyCodable]] ?? []
fields.append([
    "name": AnyCodable("documents"),
    "type": AnyCodable("file"),
    "maxSelect": AnyCodable(5),        // Maximum number of files (1 for single file)
    "maxSize": AnyCodable(5242880),     // 5MB in bytes (optional, default: 5MB)
    "mimeTypes": AnyCodable(["image/jpeg", "image/png", "application/pdf"]),
    "thumbs": AnyCodable(["100x100", "300x300"]),  // Thumbnail sizes for images
    "protected": AnyCodable(false)      // Require token for access
])

// Update collection
try await client.collections.update("example", body: ["fields": AnyCodable(fields)])
```

## Uploading Files

### Basic Upload with Create

When creating a new record, you can upload files directly using multipart form data:

```swift
import Foundation

// Method 1: Using FilePart
let imageData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/image.png"))
let filePart = FilePart(
    filename: "image.png",
    data: imageData,
    contentType: "image/png"
)

let created: JSONRecord = try await client
    .collection("example")
    .create(body: .multipart { form in
        form.addText(name: "title", value: "Hello world!")
        form.addFile(name: "cover", file: filePart)
    })

// Method 2: Multiple files
let file1 = FilePart(filename: "doc1.pdf", data: pdfData1, contentType: "application/pdf")
let file2 = FilePart(filename: "doc2.pdf", data: pdfData2, contentType: "application/pdf")

let record: JSONRecord = try await client
    .collection("example")
    .create(body: .multipart { form in
        form.addText(name: "title", value: "Document Set")
        form.addFile(name: "documents", file: file1)
        form.addFile(name: "documents", file: file2)  // Same field name for multiple files
    })
```

### Upload with Update

```swift
// Update record and upload new files
let updated: JSONRecord = try await client
    .collection("example")
    .update("RECORD_ID", body: .multipart { form in
        form.addText(name: "title", value: "Updated title")
        form.addFile(name: "cover", file: FilePart(
            filename: "new_cover.png",
            data: imageData,
            contentType: "image/png"
        ))
    })
```

### File Modifiers

You can append, prepend, or delete files using field modifiers:

```swift
// Append files (add to existing)
let updated: JSONRecord = try await client
    .collection("example")
    .update("RECORD_ID", body: .multipart { form in
        form.addFile(name: "documents+", file: newFile)  // + means append
    })

// Prepend files (add to beginning)
let updated2: JSONRecord = try await client
    .collection("example")
    .update("RECORD_ID", body: .multipart { form in
        form.addFile(name: "documents-", file: newFile)  // - means prepend
    })

// Delete specific file
let updated3: JSONRecord = try await client
    .collection("example")
    .update("RECORD_ID", body: [
        "documents-": AnyCodable("filename_to_delete.png")
    ])
```

## Getting File URLs

### Public Files

For public files (not protected), you can build URLs directly:

```swift
let record: JSONRecord = try await client
    .collection("example")
    .getOne("RECORD_ID")

// Get file URL
if let filename = (record["cover"] as? [String])?.first,
   let url = client.files.getURL(record: record, filename: filename) {
    print("File URL: \(url)")
}
```

### Protected Files

For protected files, you need to get a token first:

```swift
// Get file access token (requires authentication)
let token = try await client.files.getToken()

// Build URL with token
let record: JSONRecord = try await client
    .collection("example")
    .getOne("RECORD_ID")

if let filename = (record["document"] as? [String])?.first {
    let options = FileOptions(token: token)
    if let url = client.files.getURL(record: record, filename: filename, options: options) {
        print("Protected file URL: \(url)")
    }
}
```

### Image Thumbnails

For image files with thumbnail configuration:

```swift
let record: JSONRecord = try await client
    .collection("example")
    .getOne("RECORD_ID")

if let filename = (record["image"] as? [String])?.first {
    // Get thumbnail URL
    let options = FileOptions(thumb: "100x100")
    if let thumbnailURL = client.files.getURL(record: record, filename: filename, options: options) {
        print("Thumbnail URL: \(thumbnailURL)")
    }
    
    // Get full image
    if let fullImageURL = client.files.getURL(record: record, filename: filename) {
        print("Full image URL: \(fullImageURL)")
    }
}
```

### Download Files

To force download instead of displaying in browser:

```swift
let options = FileOptions(download: true)
if let downloadURL = client.files.getURL(record: record, filename: filename, options: options) {
    print("Download URL: \(downloadURL)")
}
```

## Complete Example

```swift
import Foundation
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate
try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password123")

// Create record with file upload
let imageData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/photo.jpg"))
let filePart = FilePart(
    filename: "photo.jpg",
    data: imageData,
    contentType: "image/jpeg"
)

let profile: JSONRecord = try await client
    .collection("profiles")
    .create(body: .multipart { form in
        form.addText(name: "name", value: "John Doe")
        form.addFile(name: "avatar", file: filePart)
    })

print("Created profile: \(profile["id"] ?? "")")

// Get file URL
if let avatar = (profile["avatar"] as? [String])?.first,
   let url = client.files.getURL(record: profile, filename: avatar) {
    print("Avatar URL: \(url)")
    
    // Download the file
    let (data, _) = try await URLSession.shared.data(from: url)
    // Use the data...
}

// Update with new file
let newImageData = try Data(contentsOf: URL(fileURLWithPath: "/path/to/new_photo.jpg"))
let updated: JSONRecord = try await client
    .collection("profiles")
    .update(profile["id"] as! String, body: .multipart { form in
        form.addFile(name: "avatar", file: FilePart(
            filename: "new_photo.jpg",
            data: newImageData,
            contentType: "image/jpeg"
        ))
    })

// Append additional files
let doc1 = FilePart(filename: "doc1.pdf", data: pdfData1, contentType: "application/pdf")
let doc2 = FilePart(filename: "doc2.pdf", data: pdfData2, contentType: "application/pdf")

let updatedWithDocs: JSONRecord = try await client
    .collection("profiles")
    .update(profile["id"] as! String, body: .multipart { form in
        form.addFile(name: "documents+", file: doc1)  // Append
        form.addFile(name: "documents+", file: doc2)  // Append
    })
```

## iOS/macOS Specific Examples

### Upload from UIImage/NSImage

```swift
#if canImport(UIKit)
import UIKit

// Convert UIImage to Data
let image = UIImage(named: "photo")!
guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

let filePart = FilePart(
    filename: "photo.jpg",
    data: imageData,
    contentType: "image/jpeg"
)

let record: JSONRecord = try await client
    .collection("photos")
    .create(body: .multipart { form in
        form.addFile(name: "image", file: filePart)
    })
#elseif canImport(AppKit)
import AppKit

// Convert NSImage to Data
let image = NSImage(named: "photo")!
guard let tiffData = image.tiffRepresentation,
      let bitmapImage = NSBitmapImageRep(data: tiffData),
      let imageData = bitmapImage.representation(using: .jpeg, properties: [:]) else { return }

let filePart = FilePart(
    filename: "photo.jpg",
    data: imageData,
    contentType: "image/jpeg"
)

let record: JSONRecord = try await client
    .collection("photos")
    .create(body: .multipart { form in
        form.addFile(name: "image", file: filePart)
    })
#endif
```

### Upload from File Picker

```swift
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

// In your view controller
func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else { return }
    
    Task {
        do {
            let fileData = try Data(contentsOf: url)
            let filePart = FilePart(
                filename: url.lastPathComponent,
                data: fileData,
                contentType: UTType(filenameExtension: url.pathExtension)?.identifier ?? "application/octet-stream"
            )
            
            let record: JSONRecord = try await client
                .collection("documents")
                .create(body: .multipart { form in
                    form.addFile(name: "file", file: filePart)
                })
            
            print("Uploaded: \(record["id"] ?? "")")
        } catch {
            print("Upload failed: \(error)")
        }
    }
}
#endif
```

## Best Practices

1. **File Size Limits**: Check collection field `maxSize` before uploading large files
2. **MIME Types**: Validate file types match the collection's `mimeTypes` configuration
3. **Protected Files**: Always get a token for protected files before accessing them
4. **Thumbnails**: Use thumbnails for images to improve performance
5. **Error Handling**: Handle file upload errors gracefully, especially for large files
6. **Progress Tracking**: For large files, consider implementing upload progress tracking using URLSession delegates

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [Authentication](./AUTHENTICATION.md)

