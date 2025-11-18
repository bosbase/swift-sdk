# LLM Documents API - Swift SDK Documentation

## Overview

The `LLMDocumentService` wraps the `/api/llm-documents` endpoints that are backed by the embedded chromem-go vector store (persisted in rqlite). Each document contains text content, optional metadata and an embedding vector that can be queried with semantic search.

## Getting Started

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Create a logical namespace for your documents
try await client.llmDocuments.createCollection(
    name: "knowledge-base",
    metadata: ["domain": "internal"]
)
```

## Insert Documents

```swift
// Insert document without ID (auto-generated)
let doc: JSONRecord = try await client.llmDocuments.insert(
    collection: "knowledge-base",
    document: LLMDocument(
        content: "Leaves are green because chlorophyll absorbs red and blue light.",
        metadata: ["topic": "biology"]
    )
)

// Insert document with custom ID
_ = try await client.llmDocuments.insert(
    collection: "knowledge-base",
    document: LLMDocument(
        id: "sky",
        content: "The sky is blue because of Rayleigh scattering.",
        metadata: ["topic": "physics"]
    )
)
```

## Query Documents

```swift
let result: JSONRecord = try await client.llmDocuments.query(
    collection: "knowledge-base",
    options: LLMQueryOptions(
        queryText: "Why is the sky blue?",
        limit: 3,
        where: ["topic": "physics"]
    )
)

if let results = result["results"]?.value as? [JSONRecord] {
    for match in results {
        if let id = match["id"]?.value as? String,
           let similarity = match["similarity"]?.value as? Double {
            print("\(id): \(similarity)")
        }
    }
}
```

## Manage Documents

```swift
// Update a document
_ = try await client.llmDocuments.update(
    collection: "knowledge-base",
    documentId: "sky",
    document: LLMDocumentUpdate(
        metadata: ["topic": "physics", "reviewed": "true"]
    )
)

// List documents with pagination
let page: JSONRecord = try await client.llmDocuments.list(
    collection: "knowledge-base",
    page: 1,
    perPage: 25
)

// Delete unwanted entries
try await client.llmDocuments.delete(
    collection: "knowledge-base",
    documentId: "sky"
)
```

## Collection Management

```swift
// List all collections
let collections: [JSONRecord] = try await client.llmDocuments.listCollections()

// Create collection
try await client.llmDocuments.createCollection(
    name: "my-collection",
    metadata: ["domain": "internal"]
)

// Delete collection
try await client.llmDocuments.deleteCollection(name: "my-collection")
```

## Complete Examples

### Example 1: Knowledge Base Setup

```swift
func setupKnowledgeBase() async throws {
    // Create collection
    try await client.llmDocuments.createCollection(
        name: "knowledge-base",
        metadata: ["domain": "internal"]
    )
    
    // Insert documents
    let documents = [
        LLMDocument(
            content: "The sky is blue because of Rayleigh scattering.",
            metadata: ["topic": "physics"]
        ),
        LLMDocument(
            content: "Leaves are green because chlorophyll absorbs red and blue light.",
            metadata: ["topic": "biology"]
        )
    ]
    
    for doc in documents {
        _ = try await client.llmDocuments.insert(
            collection: "knowledge-base",
            document: doc
        )
    }
}

// Query the knowledge base
func queryKnowledgeBase(_ question: String) async throws -> [JSONRecord] {
    let result: JSONRecord = try await client.llmDocuments.query(
        collection: "knowledge-base",
        options: LLMQueryOptions(
            queryText: question,
            limit: 5
        )
    )
    
    return result["results"]?.value as? [JSONRecord] ?? []
}
```

## HTTP Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET /api/llm-documents/collections` | List collections |
| `POST /api/llm-documents/collections/{name}` | Create collection |
| `DELETE /api/llm-documents/collections/{name}` | Delete collection |
| `GET /api/llm-documents/{collection}` | List documents |
| `POST /api/llm-documents/{collection}` | Insert document |
| `GET /api/llm-documents/{collection}/{id}` | Fetch document |
| `PATCH /api/llm-documents/{collection}/{id}` | Update document |
| `DELETE /api/llm-documents/{collection}/{id}` | Delete document |
| `POST /api/llm-documents/{collection}/documents/query` | Query by semantic similarity |

## Related Documentation

- [LangChaingo API](./LANGCHAINGO_API.md) - RAG workflows with LLM documents
- [Vector API](./VECTOR_API.md) - Vector search operations

