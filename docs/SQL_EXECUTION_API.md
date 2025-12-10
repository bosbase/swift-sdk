# SQL Execution API - Swift SDK

Run ad-hoc SQL statements against the BosBase database. All calls require superuser authentication.

**Endpoint**: `POST /api/sql/execute` with body `{ "query": "<SQL>" }`.

## Authenticate

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://127.0.0.1:8090")
try await client.collection("_superusers").authWithPassword(identity: "admin@example.com", password: "password")
```

## Execute queries

```swift
// SELECT
let select = try await client.sql.execute("SELECT id, text FROM demo1 ORDER BY id LIMIT 5")
print(select.columns ?? [])
print(select.rows ?? [])

// UPDATE with rowsAffected
let update = try await client.sql.execute("UPDATE demo1 SET text='updated via api' WHERE id='84nmscqy84lsi1t'")
print(update.rowsAffected ?? 0)

// INSERT
let insert = try await client.sql.execute("INSERT INTO demo1 (id, text) VALUES ('new-id', 'hello from SQL API')")
print(insert.rowsAffected ?? 0)

// DELETE
let removed = try await client.sql.execute("DELETE FROM demo1 WHERE id='new-id'")
print(removed.rowsAffected ?? 0)
```

## Response shape

```jsonc
{
  "columns": ["col1", "col2"], // omitted when empty
  "rows": [["v1", "v2"]],      // omitted when empty
  "rowsAffected": 3            // only present for write operations
}
```

Error handling:
- Empty queries are rejected client-side.
- Database or syntax errors surface as `ClientResponseError`.
- You can pass `headers`, `requestKey`, and other `RequestOptions` arguments via `client.sql.execute(_, headers:)` as needed.
