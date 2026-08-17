# WAU-30 — Import Management UI: API Contract (draft)

> Status: draft — for Pierre review before sub-engineer implementation.
> Author: Lead Engineer · 2026-08-14

## 1. Scope

Contract between the **Import Management UI (WAU-30)** and the **WAU backend**
(the service wrapping Stalling Editor + the AS importer WAU-32 + the WaU
pipeline WAU-1). The UI is a thin client: it lists envelopes, lets the user
select a batch, confirms, and submits. All heavy lifting is server-side.

## 2. Decisions folded in (Pierre, 2026-08-14)

| # | Question | Answer | Consequence for contract |
|---|----------|--------|--------------------------|
| 1 | Idempotency | re-submit OK | `POST /imports` is idempotent per envelope-id set; no dedupe guard, server tolerates repeat submit |
| 2 | Batch limit | 10 by 10 | hard cap **10 envelope ids per request**, enforced server-side (`400` if exceeded) |
| 3 | Polling | manual trigger only | **no job-status/polling endpoint**; UI re-reads the list to see state |
| 4 | Pipeline input | JSON array of ids → POST to pipeline API endpoint (WAU-1) | resolved 2026-08-14: backend POSTs the id list via HTTP to the pipeline-managed endpoint |
| 5 | Completion | batch processed; per-item failures in `error.failedIds` | response carries `failedIds` for partial failure |

## 3. Resources & identifiers

- **Envelope id** — the Stalling Editor identifier of a data-envelope record
  (e.g. the `ID` element / `unl://N` self-link). Opaque string to the UI.
- **Profile id** — `clarin.eu:cr1:p_1708423613607` (Data Envelope). Used by the
  importer to select the schema; the UI does not need it.

## 4. Endpoints

### 4.1 List data-envelopes

`GET /api/wau/envelopes`

Query params (all optional):

| Param | Type | Meaning |
|-------|------|---------|
| `status` | string | filter (`under construction`, `publish`, …) |
| `onlyReady` | bool | return only valid/ready envelopes |
| `page` / `limit` | int | pagination (limit default 25) |

Response `200`:

```json
{
  "items": [
    {
      "id": "unl://2",
      "selfLink": "unl://2",
      "status": "under construction",
      "valid": false,
      "incompleteFields": ["BasicMetadata.Snapshot.version", "Data"]
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 25
}
```

`incompleteFields` is a flat list of profile paths (dot-separated component
path → element name) the UI can surface as "incomplete fields" count/why.

### 4.2 Submit batch for import

`POST /api/wau/imports`

Request:

```json
{ "envelopeIds": ["unl://2", "unl://3"] }
```

Constraints:

- `envelopeIds`: 1..10 entries (decision #2). `400` if empty or >10.
- Idempotent per id-set (decision #1): submitting the same set again is safe.
  Server re-runs the same work; no duplicate guard required.

Response `202 Accepted` (submission accepted; no polling — decision #3):

```json
{
  "importId": "imp_01J",
  "accepted": true,
  "failedIds": []
}
```

Partial failure (decision #5) — batch is "processed", per-item problems listed:

```json
{
  "importId": "imp_01J",
  "accepted": true,
  "failedIds": ["unl://3"],
  "errors": [
    { "id": "unl://3", "code": "INVALID_ENVELOPE", "message": "version missing" }
  ]
}
```

## 5. Error model

```json
{ "error": { "code": "STRING", "message": "STRING", "failedIds": ["..."] } }
```

| Code | HTTP | Meaning |
|------|------|---------|
| `BATCH_TOO_LARGE` | 400 | >10 ids |
| `EMPTY_BATCH` | 400 | 0 ids |
| `INVALID_ENVELOPE` | per-item (in `errors`) | envelope fails validation |
| `IMPORT_FAILED` | per-item (in `errors`) | importer/pipeline error |

## 6. Pipeline fan-out (decision #4 — resolved)

- Pipeline input = **JSON array of envelope ids** (the `envelopeIds` list).
- The WAU backend POSTs the id list via HTTP to a **pipeline-managed API
  endpoint** (WAU-1) after AS import — fire-and-forget, no polling.
- The exact pipeline endpoint URL/path is owned by the pipeline service (WAU-1)
  and configured in the WAU backend (not hard-coded in this contract).

## 7. Non-functional

- Batch ≤ 10 enforced at the API boundary (defense in depth even though the UI
  caps selection at 10).
- Re-submit idempotent; no client-side dedupe key required.
