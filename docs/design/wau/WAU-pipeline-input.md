# WAU — Pipeline input format (decision #4) — resolved

> Lead Engineer · 2026-08-14 · decision #4 RESOLVED (Pierre, 2026-08-14).

## Findings (from Plane WAU project)

The WaU pipeline (**WAU-1 "Finalize migration pipeline"**, Python, repo
`code.huc.knaw.nl/pierreb/wau-pipeline`) ingests SIP packages by scanning
`/data/sips`:

- Each subdir of `/data/sips` = one `record_id` (a data-envelope).
- Record folder holds `metadata.json` + `files/`.
- Structure validated against `UploadStructure` / `UploadStructurePerId`
  (`backend/src/models/structure_models.py`).
- Outputs `valid_structures.json` + `invalid_records.log` (task #23).
- Export writes version subdirs named by pipeline start epoch (task #4).

Crucially, WAU-1 already tracks **"Add the IDs list input feature"** — the
pipeline must accept an explicit list of IDs, rather than always scanning all
of `/data/sips`.

## Resolution (Pierre, 2026-08-14) ✅

**Pipeline input = explicit JSON array of data-envelope IDs** (the WAU-30
selection), not a full-folder scan.

- Format: JSON array of ids — `["unl://2", "unl://3"]` (≤ 10, aligns with
  WAU-30 `POST /imports` `envelopeIds`).
- Delivery: the WAU backend **POSTs the id list via HTTP (curl-equivalent) to
  a pipeline-managed API endpoint** (WAU-1). No direct repo/CLI access needed.
- Fan-out: WAU-30 import to AS (WAU-32) → POST the same id list to the
  pipeline endpoint.

## Deferred

- Exact pipeline endpoint URL/path — owned by the pipeline service (WAU-1),
  configured in the WAU backend; not needed for WAU-30/31/32 design.
- id → `record_id` folder mapping — deferred until pipeline integration.
