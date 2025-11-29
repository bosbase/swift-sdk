# SQL API - Swift SDK Documentation

Superuser-only SQL helpers for inspecting and migrating existing databases. These APIs mirror the backend Go service endpoints and the JavaScript SDK.

## Endpoints

- `POST /api/sql/execute` — Execute arbitrary SQL and return columns/rows
- `POST /api/collections/sql/tables` — Register existing SQL tables as BosBase collections
- `POST /api/collections/sql/import` — Execute SQL definitions and register the resulting tables

> **Auth**: All operations require a superuser token (for example, authenticate against `_superusers` first).

## Execute SQL

Run ad-hoc SQL queries and get the result set:

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")

let response = try await client.sql.execute("SELECT name, type FROM sqlite_master WHERE type = 'table'")

print(response.columns ?? []) // ["name", "type"]
print(response.rows ?? [])    // [["posts", "table"], ...]
print(response.rowsAffected)  // Non-nil for UPDATE/DELETE statements
```

## Register Existing SQL Tables

Expose existing database tables as BosBase collections while preserving their schema:

```swift
let collections = try await client.collections.registerSQLTables([
    "sql_table_one",
    "sql_table_two"
])

for collection in collections {
    print(collection["name"] ?? "")
}
```

The backend adds audit columns (`created`, `updated`, `createdBy`, `updatedBy`) if they are missing and ensures default API rules are applied.

## Import SQL Table Definitions

Create tables (if needed) and register them as collections in one call:

```swift
let result = try await client.collections.importSQLTables([
    SQLTableDefinition(
        name: "legacy_orders",
        sql: """
        CREATE TABLE IF NOT EXISTS legacy_orders (
            id TEXT PRIMARY KEY,
            customer_email TEXT NOT NULL,
            total REAL NOT NULL
        );
        """
    )
])

print("Created: \(result.created.count)")
print("Skipped: \(result.skipped)") // Tables that already existed as collections
```

Use this when migrating legacy schemas or syncing tables created outside of BosBase.
