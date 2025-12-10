# Register Existing SQL Tables (Swift SDK)

Expose existing SQL tables as BosBase collections or run SQL to create-and-register tables. Both calls are superuser-only.

- `registerSQLTables(_ tables: [String])` – map existing tables to collections.
- `importSQLTables(_ tables: [SQLTableDefinition])` – optionally run SQL to create tables, then register them. Returns `{ created, skipped }`.

## Requirements
- Authenticate with a `_superusers` token.
- Each table must have a `TEXT` primary key column named `id`.
- Missing audit columns (`created`, `updated`, `createdBy`, `updatedBy`) are added automatically so default API rules work.

## Basic usage

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
try await client.collection("_superusers").authWithPassword(identity: "root@example.com", password: "hunter2")

let collections = try await client.collections.registerSQLTables([
    "projects",
    "accounts"
])

print(collections.map { $0["name"]?.value as? String ?? "" })
// ["projects", "accounts"]
```

## With request options

```swift
let collections = try await client.collections.registerSQLTables(
    ["legacy_orders"],
    query: ["trace": "reg-123"],
    headers: ["X-Trace-Id": "reg-123"]
)
```

## Create-or-register flow

```swift
let result = try await client.collections.importSQLTables([
    SQLTableDefinition(
        name: "legacy_orders",
        sql: """
        CREATE TABLE IF NOT EXISTS legacy_orders (
            id TEXT PRIMARY KEY,
            customer_email TEXT NOT NULL
        );
        """
    ),
    SQLTableDefinition(name: "reporting_view") // assumes table already exists
])

print(result.created.map { $0["name"]?.value as? String ?? "" })
print(result.skipped) // table names that already existed as collections
```

What it does:
- Generates REST collections for the provided tables.
- Applies standard default API rules (authenticated create; update/delete scoped to creator).
- Ensures audit columns exist; otherwise leaves existing schema and data untouched.
- Marks created collections with `externalTable: true` so you can distinguish them.
