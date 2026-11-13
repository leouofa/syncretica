# Syncretica REST API (`/api/v1`) Specification & Developer Reference

This document provides a comprehensive technical reference for the programmatic REST API exposed by **Syncretica** under `/api/v1`. The API is designed for external applications, researchers, and companion client environments (such as a TypeScript Model Context Protocol / MCP server) to query, manipulate, and orchestrate the entire comparative mythology catalog, vector embedding manifold, archetype clustering engine, and multi-stage LLM synthesis pipelines.

---

## 1. Architectural Overview & Conventions

### Base URL
```
http://localhost:3000/api/v1
```

### OpenAPI 3.1 Specification
Syncretica serves an introspectable OpenAPI 3.1 JSON document directly at:
```http
GET /api/v1/openapi.json
```

### Response Envelopes
All responses are formatted as JSON using a consistent envelope structure:

#### Single Resource or Action Response
```json
{
  "data": { ... },
  "meta": { ... } // optional contextual metadata
}
```

#### Collection Response (with Pagination)
```json
{
  "data": [ ... ],
  "meta": {
    "total": 1163,
    "limit": 50,
    "offset": 0
  }
}
```

#### Error Response
Standard HTTP status codes (`400 Bad Request`, `404 Not Found`, `422 Unprocessable Entity`, etc.) return an error object:
```json
{
  "error": {
    "code": "not_found",
    "message": "Couldn't find God with 'id'=9999",
    "details": ["Optional validation errors or context"]
  }
}
```

### Pagination
Collection endpoints support `limit` (default: `50`, maximum: `500`) and `offset` (default: `0`) query parameters.

### Embedding Vectors (`pgvector` 1024-float arrays)
To keep network payloads lean, endpoints returning `God` or `Myth` records include vector metadata (`embedded: boolean`, `embedding_model: string`, `embedded_at: timestamp`, `embedding_dimensions: 1024`), while the raw 1024-float array is omitted by default.
Pass `?include_embedding=true` on any individual or collection query to include the raw vector:
```json
{
  "data": {
    "id": 1,
    "name": "Zeus",
    "embedded": true,
    "embedding_model": "qwen3-embedding:0.6b",
    "embedding": [0.0123, -0.0456, 0.0891, ...]
  }
}
```

### Synchronous vs. Asynchronous Job Execution (`?sync=true`)
Long-running LLM and embedding operations (discovery, population, vector calculation) default to asynchronous execution via ActiveJob/Sidekiq (`202 Accepted` with `{ "data": { "job_id": "...", "status": "queued" } }`).
Clients can:
1. Poll the job status at `GET /api/v1/jobs/:id`.
2. Or pass `?sync=true` on single-entity actions (`POST /api/v1/gods/:id/generate_embedding?sync=true`, `POST /api/v1/pantheons/:id/populate_gods?sync=true`, `POST /api/v1/gods/:id/populate_myth?sync=true`) to block until execution completes and receive the immediate result (`200 OK`).

---

## 2. API Endpoints by Domain

### 2.1 Platform Status & Introspection

#### `GET /api/v1/status`
Returns overall health, entity counts, embedding coverage stats, and active LLM/embedding configurations.

```bash
curl -s http://localhost:3000/api/v1/status | jq
```
```json
{
  "data": {
    "status": "ok",
    "environment": "development",
    "timestamp": "2026-11-13T02:30:00Z",
    "counts": {
      "pantheons": 75,
      "gods": 1163,
      "gods_embedded": 1163,
      "myths": 1163,
      "myths_embedded": 1163,
      "cluster_snapshots": 12,
      "cluster_reports": 8
    },
    "config": {
      "embedding_model": "qwen3-embedding:0.6b",
      "embedding_api_base": "http://localhost:11434/v1",
      "embedding_dimensions": 1024,
      "llm_model": "Qwen3.6-35B-A3B-NVFP4",
      "llm_api_base": "http://localhost:11434/v1",
      "context_window": 262144,
      "digest_char_budget": 576716
    }
  }
}
```

#### `GET /api/v1/openapi.json`
Returns the complete OpenAPI 3.1.0 JSON schema.

---

### 2.2 Global Search

#### `GET /api/v1/search`
Unified semantic or keyword search across both `God` and `Myth` entities.

**Query Parameters:**
- `q` (required, string): Search query text.
- `mode` (optional, `semantic` | `keyword` | `auto`, default `auto`): When `semantic`, encodes `q` into a 1024-dim vector using `Llm::EmbeddingGenerator` and runs pgvector cosine distance search.
- `target_type` (optional, `all` | `god` | `myth`, default `all`).
- `limit` (optional, integer, default `20`).

```bash
curl -s "http://localhost:3000/api/v1/search?q=underworld+and+judgment&mode=semantic&limit=5" | jq
```

---

### 2.3 Pantheons

#### `GET /api/v1/pantheons`
List pantheons with optional keyword filter (`?q=`) and deity counts.
- `?include_gods=true`: Embeds the list of deities for each pantheon.
- `?limit=50&offset=0`: Pagination.

#### `GET /api/v1/pantheons/:id`
Fetch single pantheon details (includes `gods` by default).

#### `POST /api/v1/pantheons`
Create a new pantheon record:
```json
{
  "pantheon": {
    "name": "Etruscan",
    "description": "Deities of pre-Roman northern Italy."
  }
}
```

#### `PATCH /api/v1/pantheons/:id`
Update an existing pantheon.

#### `DELETE /api/v1/pantheons/:id`
Delete a pantheon and its associated gods and myths.

#### `POST /api/v1/pantheons/upsert_batch`
Batch upsert pantheon records matching case-insensitively on `name`:
```json
{
  "pantheons": [
    { "name": "Celtic", "description": "Gallic and Brythonic traditions." },
    { "name": "Slavic", "description": "Pre-Christian Slavic deities." }
  ]
}
```

#### `POST /api/v1/pantheons/populate`
Triggers `PopulatePantheonsJob` via LLM discovery (`?sync=true` supported).

#### `POST /api/v1/pantheons/:id/populate_gods`
Discovers and populates deities for this specific pantheon via `PopulateGodsJob` (`?sync=true` supported).

---

### 2.4 Gods

#### `GET /api/v1/gods`
List and filter deities.
- `?pantheon_id=12`: Filter by pantheon ID.
- `?pantheon=Greek`: Filter by pantheon name substring.
- `?theme=thunder`: Filter deities containing the thematic tag.
- `?q=zeus`: Keyword search in name or description.
- `?embedded=true|false`: Filter by vector embedding presence.
- `?include_embedding=true`: Include raw 1024-dim float array.
- `?include_myth=true`: Include associated decomposed myth themes.

#### `GET /api/v1/gods/search`
Semantic or keyword search scoped specifically to deities (`?q=solar+sovereign&mode=semantic&limit=10`).

#### `GET /api/v1/gods/:id`
Get full deity profile including pantheon and myth mythemes.

#### `POST /api/v1/gods`
Create a deity:
```json
{
  "god": {
    "pantheon_id": 1,
    "name": "Thor",
    "description": "Norse god of thunder and protector of mankind.",
    "themes": ["thunder", "strength", "storm", "protection"]
  }
}
```

#### `PATCH /api/v1/gods/:id`
Update a deity's attributes or themes.

#### `DELETE /api/v1/gods/:id`
Delete a deity and its associated myth.

#### `POST /api/v1/gods/upsert_batch`
Batch upsert deities scoped to a pantheon:
```json
{
  "pantheon_id": 1,
  "gods": [
    { "name": "Odin", "description": "Allfather.", "themes": ["wisdom", "war", "magic"] },
    { "name": "Freya", "description": "Goddess of love and battle.", "themes": ["love", "fertility", "seidr"] }
  ]
}
```

#### `GET /api/v1/gods/:id/neighbors`
Find nearest deities in the 1024-dimensional semantic manifold using pgvector cosine distance (`?limit=10&pantheon_id=optional`).

#### `POST /api/v1/gods/:id/generate_embedding`
Calculate vector embedding for the deity (`?sync=true` supported).

#### `POST /api/v1/gods/:id/populate_myth`
Discover and generate 8–10 structured mythological themes for this god via LLM (`?sync=true` supported).

#### `POST /api/v1/gods/populate`
Trigger bulk LLM discovery across all or a single pantheon (`?pantheon_id=12&sync=false`).

---

### 2.5 Myths

#### `GET /api/v1/myths`
List and filter myths.
- `?god_id=5`: Filter by god.
- `?pantheon_id=1`: Filter by pantheon.
- `?theme=chaos`: Filter myths whose proposition keys or values match.
- `?q=slaying`: Search myth propositions.
- `?include_embedding=true`: Include raw vector.

#### `GET /api/v1/myths/search`
Semantic or keyword search scoped to myth propositions (`?q=creation+from+dismemberment&mode=semantic`).

#### `GET /api/v1/myths/:id`
Get myth detail, including its structured 8–10 themes and associated deity.

#### `POST /api/v1/myths`
Create or upsert a myth for a deity:
```json
{
  "myth": {
    "god_id": 4,
    "themes": {
      "Chaoskampf": "Marduk slays the primordial dragon Tiamat.",
      "Civic Order": "Babylon is founded as the navel of the cosmos."
    }
  }
}
```

#### `PATCH /api/v1/myths/:id`
Update myth themes.

#### `DELETE /api/v1/myths/:id`
Delete a myth.

#### `GET /api/v1/myths/:id/neighbors`
Find nearest structural mythologies across world traditions by cosine distance (`?limit=10`).

#### `POST /api/v1/myths/:id/generate_embedding`
Generate vector embedding for the myth (`?sync=true` supported).

#### `POST /api/v1/myths/populate`
Trigger bulk myth discovery for all deities or a single deity (`?god_id=5`).

---

### 2.6 Live Clustering & Snapshots

#### `GET /api/v1/clusters`
Computes live connected-components vector clusters without modifying the database.
- `target_type`: `God` (default) or `Myth`.
- `level`: `1` to `15` (default `5`, see threshold table in README).
- `full_coverage`: `true` or `false` (forces 100% catalog assignment / zero singletons).
- `force`: `true` to bypass Rails cache.

Returns discovered multi-member clusters, shared themes, pantheons, and unclustered singletons.

#### `POST /api/v1/clusters/snapshot` (or `POST /api/v1/cluster_snapshots`)
Computes the clustering and immediately freezes it into an immutable database record:
```json
{
  "target_type": "God",
  "level": 15,
  "full_coverage": true,
  "title": "Full Catalog Zero-Singleton Snapshot (15)"
}
```

#### `GET /api/v1/cluster_snapshots`
List saved snapshots (`?target_type=God|Myth`).

#### `GET /api/v1/cluster_snapshots/:id`
Get snapshot details including all discovered `cluster_groups`, member counts, and generated synthesis reports.
- `?include_groups=true`
- `?include_members=true`
- `?include_reports=true`

#### `DELETE /api/v1/cluster_snapshots/:id`
Delete a snapshot and its cascaded cluster groups and reports.

#### `GET /api/v1/cluster_snapshots/:cluster_snapshot_id/cluster_groups`
List all archetype groups belonging to a snapshot.

#### `GET /api/v1/cluster_groups/:id`
Get a specific cluster group with all member deities or myths.

---

### 2.7 Multi-Stage Synthesis Reports

#### `GET /api/v1/cluster_reports`
List generated scholarly reports (`?cluster_snapshot_id=`, `?target_type=`, `?status=completed`, `?is_detailed=true`).

#### `GET /api/v1/cluster_reports/:id`
Get full report status, progress percentage, markdown content, citations, and sub-reports.
- `?include_summaries=true`: Includes Phase 1 per-cluster analyses.
- `?include_sub_reports=true`: Includes Phase 2 batch narrative analyses.

#### `POST /api/v1/cluster_reports` (or `POST /api/v1/cluster_snapshots/:cluster_snapshot_id/cluster_reports`)
Initiate a 2-Phase Map-Reduce report on a saved snapshot:
```json
{
  "cluster_snapshot_id": 1,
  "prompt": "Analyze cross-cultural archetypes of sacred metallurgy and volcanic divine power."
}
```

#### `POST /api/v1/cluster_reports/:id/deep_synthesis`
Initiates a 3-Phase Hierarchical Deep Synthesis monograph, reusing Phase 1 summaries from the parent report:
```json
{
  "batch_size": 5
}
```

#### `GET /api/v1/cluster_reports/:cluster_report_id/summaries`
List individual Phase 1 cluster summaries.

#### `GET /api/v1/cluster_report_summaries/:id`
Get a single Phase 1 summary.

#### `GET /api/v1/cluster_reports/:cluster_report_id/sub_reports`
List intermediate Phase 2 batch analyses.

#### `GET /api/v1/cluster_sub_reports/:id`
Get a single Phase 2 batch analysis.

---

### 2.8 Background Jobs

#### `GET /api/v1/jobs`
List recently tracked asynchronous operations (`?limit=20`).

#### `GET /api/v1/jobs/:id`
Poll the execution state, progress, and result of an ActiveJob/Sidekiq background task:
```bash
curl -s http://localhost:3000/api/v1/jobs/21b96495-231a-4299-8dcf-f2771d9d7b88 | jq
```
```json
{
  "data": {
    "job_id": "21b96495-231a-4299-8dcf-f2771d9d7b88",
    "job_class": "PopulateGodsJob",
    "status": "running",
    "message": "Discovering gods for Norse (2/75)...",
    "progress": { "current": 2, "total": 75, "pantheon": "Norse" },
    "enqueued_at": "2026-11-13T02:31:00Z",
    "started_at": "2026-11-13T02:31:01Z",
    "completed_at": null
  }
}
```

---

### 2.9 Settings

#### `GET /api/v1/settings`
Returns embedding completion stats for Gods and Myths, model parameters, and context window presets.

#### `PATCH /api/v1/settings/context_window`
Dynamically update the active LLM context window:
```json
{
  "context_window": 131072
}
```

#### `POST /api/v1/settings/generate_embeddings`
Enqueue bulk embedding generation:
```json
{
  "model_type": "God",
  "only_missing": true
}
```

---

## 3. TypeScript MCP Client Integration Example

Below is a minimal Node/TypeScript snippet demonstrating how an MCP server or client tool can interact with Syncretica:

```typescript
import axios from "axios";

const client = axios.create({
  baseURL: "http://localhost:3000/api/v1",
  timeout: 60000
});

// Tool: Search cross-cultural deities or mythologies
export async function searchSyncretica(query: string, mode: "semantic" | "keyword" = "semantic") {
  const res = await client.get("/search", { params: { q: query, mode, limit: 10 } });
  return res.data.data;
}

// Tool: Find nearest counterpart deities to a known god
export async function getCounterparts(godId: number, limit = 5) {
  const res = await client.get(`/gods/${godId}/neighbors`, { params: { limit } });
  return res.data.data;
}

// Tool: Run live clustering on myths and freeze snapshot
export async function createFullCoverageSnapshot(title: string) {
  const res = await client.post("/clusters/snapshot", {
    target_type: "Myth",
    level: 15,
    full_coverage: true,
    title
  });
  return res.data.data;
}
```
