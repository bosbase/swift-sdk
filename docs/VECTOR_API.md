# Vector Database API - Swift SDK Documentation

Vector database operations for semantic search, RAG (Retrieval-Augmented Generation), and AI applications.

> **Note**: Vector operations are currently implemented using sqlite-vec but are designed with abstraction in mind to support future vector database providers.

> 📖 **Reference**: This guide mirrors the [JavaScript SDK Vector API documentation](../js-sdk/docs/VECTOR_API.md) but uses Swift syntax and examples.

## Overview

The Vector API provides a unified interface for working with vector embeddings, enabling you to:
- Store and search vector embeddings
- Perform similarity search
- Build RAG applications
- Create recommendation systems
- Enable semantic search capabilities

## Getting Started

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate as superuser (vectors require superuser auth)
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")
```

## Types

### VectorEmbedding
Array of numbers representing a vector embedding.

```swift
typealias VectorEmbedding = [Double]
```

### VectorDocument
A vector document with embedding, metadata, and optional content.

```swift
public struct VectorDocument: Codable {
    public var id: String?                    // Unique identifier (auto-generated if not provided)
    public var vector: VectorEmbedding        // The vector embedding
    public var metadata: VectorMetadata?       // Optional metadata (key-value pairs)
    public var content: String?               // Optional text content
}
```

### VectorSearchOptions
Options for vector similarity search.

```swift
public struct VectorSearchOptions: Codable {
    public var queryVector: VectorEmbedding        // Query vector to search for
    public var limit: Int?                         // Max results (default: 10, max: 100)
    public var filter: VectorMetadata?             // Optional metadata filter
    public var minScore: Double?                   // Minimum similarity score threshold
    public var maxDistance: Double?               // Maximum distance threshold
    public var includeDistance: Bool?              // Include distance in results
    public var includeContent: Bool?               // Include full document content
}
```

### VectorSearchResult
Result from a similarity search.

```swift
public struct VectorSearchResult: Codable {
    public var document: VectorDocument    // The matching document
    public var score: Double               // Similarity score (0-1, higher is better)
    public var distance: Double?           // Distance metric (optional)
}
```

## Collection Management

### Create Collection

Create a new vector collection with specified dimension and distance metric.

```swift
let config = VectorCollectionConfig(
    dimension: 384,      // Vector dimension (default: 384)
    distance: .cosine    // Distance metric: .cosine (default), .l2, .dot
)

try await client.vectors.createCollection("documents", config: config)

// Minimal example (uses defaults)
try await client.vectors.createCollection("documents", config: VectorCollectionConfig())
```

**Parameters:**
- `name` (String): Collection name
- `config` (VectorCollectionConfig):
  - `dimension` (Int, optional): Vector dimension. Default: 384
  - `distance` (VectorDistance, optional): Distance metric. Default: `.cosine`
  - Options: `.cosine`, `.l2`, `.dot`

### List Collections

Get all available vector collections.

```swift
let collections: [VectorCollectionInfo] = try await client.vectors.listCollections()

for collection in collections {
    print("Collection: \(collection.name)")
    print("Dimension: \(collection.dimension)")
    print("Distance: \(collection.distance)")
}
```

### Delete Collection

```swift
try await client.vectors.deleteCollection("documents")
```

### Update Collection

```swift
let config = VectorCollectionConfig(
    dimension: 512,
    distance: .l2
)

try await client.vectors.updateCollection("documents", config: config)
```

## Document Operations

### Insert Document

Insert a single vector document.

```swift
let document = VectorDocument(
    id: nil,  // Auto-generated if not provided
    vector: [0.1, 0.2, 0.3, /* ... */],  // Your embedding vector
    metadata: [
        "title": AnyCodable("Document Title"),
        "category": AnyCodable("tech")
    ],
    content: "This is the document content"
)

let response: VectorInsertResponse = try await client.vectors.insert(
    document,
    collection: "documents"
)

print("Inserted document ID: \(response.id)")
```

### Batch Insert

Insert multiple documents at once for better performance.

```swift
let documents = [
    VectorDocument(
        vector: embedding1,
        metadata: ["title": AnyCodable("Doc 1")],
        content: "Content 1"
    ),
    VectorDocument(
        vector: embedding2,
        metadata: ["title": AnyCodable("Doc 2")],
        content: "Content 2"
    )
]

let options = VectorBatchInsertOptions(documents: documents)

let response: VectorBatchInsertResponse = try await client.vectors.batchInsert(
    options,
    collection: "documents"
)

print("Inserted \(response.inserted) documents")
```

### Get Document

Retrieve a document by ID.

```swift
let document: VectorDocument = try await client.vectors.get(
    "DOCUMENT_ID",
    collection: "documents"
)

print("Content: \(document.content ?? "")")
```

### Update Document

Update an existing document.

```swift
let updated = VectorDocument(
    id: "DOCUMENT_ID",
    vector: newEmbedding,
    metadata: ["title": AnyCodable("Updated Title")],
    content: "Updated content"
)

let response: VectorInsertResponse = try await client.vectors.update(
    documentId: "DOCUMENT_ID",
    document: updated,
    collection: "documents"
)
```

### Delete Document

```swift
try await client.vectors.delete(
    "DOCUMENT_ID",
    collection: "documents"
)
```

### List Documents

List documents with pagination.

```swift
let result: JSONRecord = try await client.vectors.list(
    collection: "documents",
    page: 1,
    perPage: 20
)

if let items = result["items"]?.value as? [[String: AnyCodable]] {
    print("Found \(items.count) documents")
}
```

## Search Operations

### Basic Search

Perform similarity search.

```swift
let queryVector: VectorEmbedding = [0.1, 0.2, 0.3, /* ... */]  // Your query embedding

let searchOptions = VectorSearchOptions(
    queryVector: queryVector,
    limit: 10,
    includeDistance: true,
    includeContent: true
)

let response: VectorSearchResponse = try await client.vectors.search(
    options: searchOptions,
    collection: "documents"
)

for result in response.results {
    print("Score: \(result.score)")
    print("Content: \(result.document.content ?? "")")
    if let distance = result.distance {
        print("Distance: \(distance)")
    }
}
```

### Search with Metadata Filter

Filter results by metadata.

```swift
let searchOptions = VectorSearchOptions(
    queryVector: queryVector,
    limit: 10,
    filter: [
        "category": AnyCodable("tech"),
        "status": AnyCodable("published")
    ],
    includeContent: true
)

let response: VectorSearchResponse = try await client.vectors.search(
    options: searchOptions,
    collection: "documents"
)
```

### Search with Score Threshold

Only return results above a minimum score.

```swift
let searchOptions = VectorSearchOptions(
    queryVector: queryVector,
    limit: 10,
    minScore: 0.7,  // Only results with score >= 0.7
    includeContent: true
)

let response: VectorSearchResponse = try await client.vectors.search(
    options: searchOptions,
    collection: "documents"
)
```

## Complete Example

```swift
import BosBase

let client = try BosBaseClient(baseURLString: "http://localhost:8090")

// Authenticate
try await client
    .collection("_superusers")
    .authWithPassword(identity: "admin@example.com", password: "password")

// Create collection
let config = VectorCollectionConfig(
    dimension: 384,
    distance: .cosine
)
try await client.vectors.createCollection("articles", config: config)

// Insert documents
let documents = [
    VectorDocument(
        vector: generateEmbedding(text: "Swift programming language"),
        metadata: [
            "title": AnyCodable("Swift Guide"),
            "category": AnyCodable("programming")
        ],
        content: "Swift is a powerful programming language..."
    ),
    VectorDocument(
        vector: generateEmbedding(text: "iOS development"),
        metadata: [
            "title": AnyCodable("iOS Development"),
            "category": AnyCodable("mobile")
        ],
        content: "iOS development with Swift..."
    )
]

let batchOptions = VectorBatchInsertOptions(documents: documents)
let batchResponse: VectorBatchInsertResponse = try await client.vectors.batchInsert(
    batchOptions,
    collection: "articles"
)

print("Inserted \(batchResponse.inserted) documents")

// Search
let queryEmbedding = generateEmbedding(text: "Swift programming")
let searchOptions = VectorSearchOptions(
    queryVector: queryEmbedding,
    limit: 5,
    filter: ["category": AnyCodable("programming")],
    minScore: 0.6,
    includeContent: true,
    includeDistance: true
)

let searchResponse: VectorSearchResponse = try await client.vectors.search(
    options: searchOptions,
    collection: "articles"
)

print("Found \(searchResponse.results.count) results:")
for result in searchResponse.results {
    print("  Score: \(result.score)")
    print("  Title: \(result.document.metadata?["title"] ?? "")")
    print("  Content: \(result.document.content ?? "")")
}

// Helper function to generate embeddings (you'd use an actual embedding model)
func generateEmbedding(text: String) -> VectorEmbedding {
    // In practice, use an embedding model like OpenAI, Cohere, etc.
    // This is just a placeholder
    return Array(repeating: 0.0, count: 384)
}
```

## RAG (Retrieval-Augmented Generation) Example

```swift
import BosBase

class RAGService {
    let client: BosBaseClient
    
    init() throws {
        client = try BosBaseClient(baseURLString: "http://localhost:8090")
    }
    
    func searchRelevantDocuments(query: String, limit: Int = 5) async throws -> [VectorSearchResult] {
        // Generate query embedding (use your embedding model)
        let queryEmbedding = try await generateEmbedding(for: query)
        
        // Search vector database
        let searchOptions = VectorSearchOptions(
            queryVector: queryEmbedding,
            limit: limit,
            minScore: 0.7,
            includeContent: true
        )
        
        let response: VectorSearchResponse = try await client.vectors.search(
            options: searchOptions,
            collection: "knowledge_base"
        )
        
        return response.results
    }
    
    func answerQuestion(question: String) async throws -> String {
        // 1. Search for relevant documents
        let results = try await searchRelevantDocuments(query: question)
        
        // 2. Build context from retrieved documents
        let context = results
            .map { $0.document.content ?? "" }
            .joined(separator: "\n\n")
        
        // 3. Generate answer using LLM with context
        // (This would use your LLM service)
        let answer = try await generateAnswer(question: question, context: context)
        
        return answer
    }
    
    // Placeholder functions - implement with your embedding/LLM services
    func generateEmbedding(for text: String) async throws -> VectorEmbedding {
        // Use OpenAI, Cohere, or other embedding service
        return []
    }
    
    func generateAnswer(question: String, context: String) async throws -> String {
        // Use OpenAI, Anthropic, or other LLM service
        return ""
    }
}
```

## Best Practices

1. **Dimension Consistency**: Ensure all vectors in a collection have the same dimension
2. **Distance Metric**: Choose the right distance metric for your use case:
   - `.cosine`: Good for normalized vectors, measures angle similarity
   - `.l2`: Euclidean distance, good for magnitude-sensitive vectors
   - `.dot`: Dot product, good for normalized vectors
3. **Batch Operations**: Use batch insert for better performance when inserting multiple documents
4. **Metadata Filtering**: Use metadata filters to narrow search results efficiently
5. **Score Thresholds**: Set appropriate `minScore` to filter low-quality matches
6. **Content Storage**: Store content in documents if you need it for RAG, otherwise use metadata

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [Authentication](./AUTHENTICATION.md)

