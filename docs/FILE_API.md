# File API - Swift SDK Documentation

## Overview

The File API provides endpoints for downloading and accessing files stored in collection records. It supports thumbnail generation for images, protected file access with tokens, and force download options.

**Key Features:**
- Download files from collection records
- Generate thumbnails for images (crop, fit, resize)
- Protected file access with short-lived tokens
- Force download option for any file type
- Automatic content-type detection
- Support for Range requests and caching

**Backend Endpoints:**
- `GET /api/files/{collection}/{recordId}/{filename}` - Download/fetch file
- `POST /api/files/token` - Generate protected file token

## Download / Fetch File

Downloads a single file resource from a record.

### Basic Usage

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

// Get a record with a file field
let record: JSONRecord = try await client
    .collection("posts")
    .getOne("RECORD_ID")

// Get the file URL
if let filename = record["image"]?.value as? String,
   let fileURL = client.files.getURL(record: record, filename: filename) {
    // Use the URL
    print("File URL: \(fileURL)")
}
```

### File URL Structure

The file URL follows this pattern:
```
/api/files/{collectionIdOrName}/{recordId}/{filename}
```

Example:
```
http://127.0.0.1:8090/api/files/posts/abc123/photo_xyz789.jpg
```

## Thumbnails

Generate thumbnails for image files on-the-fly.

### Thumbnail Formats

The following thumbnail formats are supported:

| Format | Example | Description |
|--------|---------|-------------|
| `WxH` | `100x300` | Crop to WxH viewbox (from center) |
| `WxHt` | `100x300t` | Crop to WxH viewbox (from top) |
| `WxHb` | `100x300b` | Crop to WxH viewbox (from bottom) |
| `WxHf` | `100x300f` | Fit inside WxH viewbox (without cropping) |
| `0xH` | `0x300` | Resize to H height preserving aspect ratio |
| `Wx0` | `100x0` | Resize to W width preserving aspect ratio |

### Using Thumbnails

```swift
// Get thumbnail URL
if let filename = record["image"]?.value as? String {
    let thumbURL = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(thumb: "100x100")
    )
    
    // Different thumbnail sizes
    let smallThumb = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(thumb: "50x50")
    )
    
    let mediumThumb = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(thumb: "200x200")
    )
    
    let largeThumb = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(thumb: "500x500")
    )
    
    // Fit thumbnail (no cropping)
    let fitThumb = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(thumb: "200x200f")
    )
    
    // Resize to specific width
    let widthThumb = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(thumb: "300x0")
    )
    
    // Resize to specific height
    let heightThumb = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(thumb: "0x200")
    )
}
```

### Thumbnail Behavior

- **Image Files Only**: Thumbnails are only generated for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Non-Image Files**: For non-image files, the thumb parameter is ignored and the original file is returned
- **Caching**: Thumbnails are cached and reused if already generated
- **Fallback**: If thumbnail generation fails, the original file is returned
- **Field Configuration**: Thumb sizes must be defined in the file field's `thumbs` option or use default `100x100`

## Protected Files

Protected files require a special token for access, even if you're authenticated.

### Getting a File Token

```swift
// Must be authenticated first
try await client
    .collection("users")
    .authWithPassword(identity: "user@example.com", password: "password")

// Get file token
let token = try await client.files.getToken()

print("Token: \(token)") // Short-lived JWT token
```

### Using Protected File Token

```swift
// Get protected file URL with token
if let filename = record["document"]?.value as? String {
    let protectedFileURL = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(token: token)
    )
    
    // Access the file
    if let url = protectedFileURL {
        let data = try Data(contentsOf: url)
        // Use the file data
    }
}
```

### Protected File Example

```swift
func displayProtectedImage(recordId: String) async throws {
    // Authenticate
    try await client
        .collection("users")
        .authWithPassword(identity: "user@example.com", password: "password")
    
    // Get record
    let record: JSONRecord = try await client
        .collection("documents")
        .getOne(recordId)
    
    // Get file token
    let token = try await client.files.getToken()
    
    // Get protected file URL
    if let filename = record["thumbnail"]?.value as? String {
        let imageURL = client.files.getURL(
            record: record,
            filename: filename,
            options: FileOptions(
                token: token,
                thumb: "300x300"
            )
        )
        
        // Display image (in UI framework)
        print("Image URL: \(imageURL?.absoluteString ?? "")")
    }
}
```

### Token Lifetime

- File tokens are short-lived (typically expires after a few minutes)
- Tokens are associated with the authenticated user/superuser
- Generate a new token if the previous one expires

## Force Download

Force files to download instead of being displayed in the browser.

```swift
// Force download
if let filename = record["document"]?.value as? String {
    let downloadURL = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(download: true)
    )
    
    // Use the download URL
    if let url = downloadURL {
        // Trigger download (platform-specific)
        #if canImport(UIKit)
        // iOS: Use URLSession or WKWebView
        #elseif canImport(AppKit)
        // macOS: Use NSWorkspace
        NSWorkspace.shared.open(url)
        #endif
    }
}
```

## Complete Examples

### Example 1: Image Gallery

```swift
func displayImageGallery(recordId: String) async throws {
    let record: JSONRecord = try await client
        .collection("posts")
        .getOne(recordId)
    
    let images: [String] = {
        if let imagesArray = record["images"]?.value as? [String] {
            return imagesArray
        } else if let singleImage = record["image"]?.value as? String {
            return [singleImage]
        }
        return []
    }()
    
    for filename in images {
        // Thumbnail for gallery
        if let thumbURL = client.files.getURL(
            record: record,
            filename: filename,
            options: FileOptions(thumb: "200x200")
        ) {
            print("Thumbnail: \(thumbURL)")
        }
        
        // Full image URL
        if let fullURL = client.files.getURL(record: record, filename: filename) {
            print("Full image: \(fullURL)")
        }
    }
}
```

### Example 2: File Download Handler

```swift
func downloadFile(recordId: String, filename: String) async throws {
    let record: JSONRecord = try await client
        .collection("documents")
        .getOne(recordId)
    
    // Get download URL
    if let downloadURL = client.files.getURL(
        record: record,
        filename: filename,
        options: FileOptions(download: true)
    ) {
        // Download the file
        let data = try Data(contentsOf: downloadURL)
        
        // Save to file system
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        try data.write(to: fileURL)
        
        print("File saved to: \(fileURL.path)")
    }
}
```

### Example 3: Protected File Viewer

```swift
func viewProtectedFile(recordId: String) async throws {
    // Authenticate
    if !client.authStore.isValid() {
        try await client
            .collection("users")
            .authWithPassword(identity: "user@example.com", password: "password")
    }
    
    // Get record
    let record: JSONRecord = try await client
        .collection("private_docs")
        .getOne(recordId)
    
    // Get token
    let token: String
    do {
        token = try await client.files.getToken()
    } catch {
        print("Failed to get file token: \(error)")
        return
    }
    
    // Get file URL
    if let filename = record["file"]?.value as? String {
        let fileURL = client.files.getURL(
            record: record,
            filename: filename,
            options: FileOptions(token: token)
        )
        
        // Display based on file type
        let ext = (filename as NSString).pathExtension.lowercased()
        
        if ["jpg", "jpeg", "png", "gif", "webp"].contains(ext) {
            // Display image
            print("Image URL: \(fileURL?.absoluteString ?? "")")
        } else if ["pdf"].contains(ext) {
            // Display PDF
            print("PDF URL: \(fileURL?.absoluteString ?? "")")
        } else {
            // Download other files
            try await downloadFile(recordId: recordId, filename: filename)
        }
    }
}
```

## Error Handling

```swift
do {
    if let filename = record["image"]?.value as? String,
       let fileURL = client.files.getURL(record: record, filename: filename) {
        // Verify URL is valid
        let data = try Data(contentsOf: fileURL)
        print("File loaded successfully")
    } else {
        print("Invalid file URL")
    }
} catch {
    print("File access error: \(error)")
}
```

### Protected File Token Error Handling

```swift
func getProtectedFileURL(record: JSONRecord, filename: String) async throws -> URL? {
    do {
        // Get token
        let token = try await client.files.getToken()
        
        // Get file URL
        return client.files.getURL(
            record: record,
            filename: filename,
            options: FileOptions(token: token)
        )
    } catch let error as ClientResponseError {
        if error.status == 401 {
            print("Not authenticated")
            // Redirect to login
        } else if error.status == 403 {
            print("No permission to access file")
        } else {
            print("Failed to get file token: \(error)")
        }
        return nil
    } catch {
        print("Unexpected error: \(error)")
        return nil
    }
}
```

## Best Practices

1. **Use Thumbnails for Lists**: Use thumbnails when displaying images in lists/grids to reduce bandwidth
2. **Lazy Loading**: Load images on demand to improve performance
3. **Cache Tokens**: Store file tokens and reuse them until they expire
4. **Error Handling**: Always handle file loading errors gracefully
5. **Content-Type**: Let the server handle content-type detection automatically
6. **Range Requests**: The API supports Range requests for efficient video/audio streaming
7. **Caching**: Files are cached with a 30-day cache-control header
8. **Security**: Always use tokens for protected files, never expose them in client-side code

## Thumbnail Size Guidelines

| Use Case | Recommended Size |
|----------|-----------------|
| Profile picture | `100x100` or `150x150` |
| List thumbnails | `200x200` or `300x300` |
| Card images | `400x400` or `500x500` |
| Gallery previews | `300x300f` (fit) or `400x400f` |
| Hero images | Use original or `800x800f` |
| Avatar | `50x50` or `75x75` |

## Limitations

- **Thumbnails**: Only work for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Protected Files**: Require authentication to get tokens
- **Token Expiry**: File tokens expire after a short period (typically minutes)
- **File Size**: Large files may take time to generate thumbnails on first request
- **Thumb Sizes**: Must match sizes defined in field configuration or use default `100x100`

## Related Documentation

- [Files Upload and Handling](./FILES.md) - Uploading and managing files
- [API Records](./API_RECORDS.md) - Working with records
- [Collections](./COLLECTIONS.md) - Collection configuration

