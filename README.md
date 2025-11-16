# BosBase Swift SDK

Swift Package Manager SDK for interacting with the BosBase HTTP API from iOS, macOS, tvOS, watchOS, and server-side Swift apps. The API surface mirrors the official JavaScript SDK so you can authenticate records, run CRUD queries, and manage collections from Swift.

## Installation

Add BosBase as a dependency inside `Package.swift`:

```swift
let package = Package(
    dependencies: [
        .package(url: "https://github.com/bosbase/swift-sdk.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: [
                .product(name: "BosBase", package: "swift-sdk")
            ]
        )
    ]
)
```

Or from Xcode, go to **File → Add Packages…** and point it at this repository.

## Quick Start

```swift
import BosBase

let client = BosBaseClient(baseURL: URL(string: "http://127.0.0.1:8090")!)

// Authenticate an auth collection record
let auth = try await client
    .collection("users")
    .authWithPassword(identity: "test@example.com", password: "123456")

// List records with filter and expand
let posts: ListResult<JSONRecord> = try await client
    .collection("posts")
    .getList(filter: client.filter("status = {:status}", params: ["status": true]), expand: "author")

// Create a new record using JSON body
struct PostPayload: Encodable { let title: String }
let created: JSONRecord = try await client
    .collection("posts")
    .create(body: PostPayload(title: "Hello"))
```

## Major Features

- ✅ Fully async/await client powered by `URLSession`
- ✅ Shared `AuthStore` that keeps the auth token + record in memory
- ✅ Record CRUD helpers (`getList`, `getFullList`, `getOne`, `create`, `update`, `delete`, `getCount`)
- ✅ Record authentication helpers including OAuth2 popup/code, OTP, password reset/verification/email change (`authWithPassword`, `authRefresh`, `authWithOTP`, `authWithOAuth2`, `authWithOAuth2Code`, `requestOTP`, `requestPasswordReset`, `confirmPasswordReset`, `requestVerification`, `confirmVerification`, `requestEmailChange`, `confirmEmailChange`, `impersonate`, `listAuthMethods`)
- ✅ Collection management helpers (`createBase`, `createAuth`, `createView`, `getScaffolds`, `importCollections`, `truncate`)
- ✅ Vector, LLM Document, LangChaingo, Cache, Settings, Logs, Health, Cron, and Backup services mirroring the Go/JS APIs
- ✅ Batch operations (with file/FormData support via `createBatch()`) and realtime subscriptions powered by the BosBase SSE endpoint
- ✅ File helpers for creating protected URLs and issuing download tokens
- ✅ Filter builder compatible with the JS SDK placeholder syntax
- ✅ Configurable `beforeSend` / `afterSend` hooks for custom logging or signing
- ✅ Multipart uploads via `RequestBody.multipart` & `FilePart`

## Request Bodies & File Uploads

All service methods accept a `RequestBody`. Use `.json(payload)` for JSON payloads or `.multipart { form in ... }` for uploads:

```swift
let record: JSONRecord = try await client.collection("docs").create(body: .multipart { form in
    form.addText(name: "title", value: "Document")
    form.addFile(name: "file", file: FilePart(filename: "doc.pdf", data: data, contentType: "application/pdf"))
})
```

For convenience there are overloads that take any `Encodable` type and automatically wrap it in `.json`.

## Hooks

```swift
client.beforeSend = { request in
    request.setValue("MyApp/1.0", forHTTPHeaderField: "User-Agent")
}

client.afterSend = { response, data in
    if response.statusCode == 401 { client.authStore.clear() }
    return data
}
```

## Testing

`swift test` runs the lightweight unit tests covering the filter builder, `AuthStore`, and URL builder logic.
