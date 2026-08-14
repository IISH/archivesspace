# WAU-31 / WAU-32 — Component Specs (refined)

> Refined against the data-envelope example Pierre linked (GitLab snippet
> `6032109`, `data-envelope-example.json`, profile `clarin.eu:cr1:p_1708423613607`).
> Source file: `docs/design/wau/data-envelope-example.json`.

## 0. What the example is

Two parts in one JSON object:

1. **`content`** — the *profile* (schema definition): a tree of `Component` /
   `Element` nodes. **277 nodes = 72 Components + 205 Elements**.
2. **`record`** — a *data-envelope instance*: array of components
   (`Header`, `Resources`, `Components`), each `Element` carrying a `value`.

Profile metadata: `nr: 2`, `id: clarin.eu:cr1:p_1708423613607`,
`when: 1758203230` (epoch).

## 1. Profile shape (relevant to WAU-31)

Root = Component **`DataEnvelope`** with 10 top-level children:

| Node | Kind | Cardinality | Notes |
|------|------|-------------|-------|
| `institute` | Element | 1..1 | closed enum (NL-AsdHI, NL-AsdIISG, NL-AsdMI, NL-AsdNIOD) |
| `ID` | Element | 1..1 | string, DisplayPriority |
| `parent` | Element | 0..1 | `class: skosType`, autoCompleteURI → SKOS lookup |
| `status` | Element | 1..1 | closed enum (`under construction`, `publish`), `readonly` |
| `BasicInformation` | Component | 1..1 | title, contact, dates, author, feedback |
| `BasicMetadata` | Component | 1..1 | snapshot, dates, creators, distribution, licensing, versioning |
| `Data` | Component | 1..unbounded | repeatable data descriptions/provenance |
| `Uses` | Component | 1..1 | purposes, use cases, ML/AI, sampling |
| `HumanPerspective` | Component | 1..1 | annotators, creator positionality |
| `DDB` | Component | 0..1 | optional DDB block (description, project, links, contacts, directory) |

### ValueScheme type vocabulary (observed)

- Scalar: `string`, `date`, `gYear`, `decimal`, `int`, `anyURI`
- Closed enum: `ValueScheme` = JSON array of `{"value": ...}` objects
- Special attributes: `Multilingual`, `class` (`skosType` | `status`),
  `autoCompleteURI` (SKOS endpoint), `readonly`, `duplicate`, `once`,
  `DisplayPriority`, `explanation`, `validation`, `inputField`, `width`/`height`.

## 2. WAU-31 — Ruby plugin (new profile) — refined

Implement the **Data Envelope** profile in ArchivesSpace as a record type,
following the `hello_world` plugin structure (IISH fork
`howtodo-plugin-development`).

Mapping rules (do **not** flatten 277 nodes to 277 fields):

- **Component → nested subrecord**. Repeating when `CardinalityMax = unbounded`
  (e.g. `Data`, `publishingOrganisation`, `funding`).
- **Element → field**, typed from `ValueScheme`:
  - `string`/`date`/`gYear`/`decimal`/`int`/`anyURI` → native AS field types
    (text, date, real/integer, URI).
  - closed enum array → **controlled vocabulary / enumeration** (AS enum or
    controlled value list).
- **`class: "skosType"` + `autoCompleteURI`** → controlled-value reference
  (SKOS concept link), not free text. Preserve the `autoCompleteURI` mapping.
- **`class: "status"` + `readonly`** → lifecycle status field (system-managed).
- **`Multilingual: "true"`** → AS `lang_materials` (multi-language).
- **CardinalityMin/Max** → required (`1..1`) vs optional vs repeatable
  (`..unbounded`).

Data-envelope exists **both** as a standalone AS record **and** as a nested
subrecord on Resource (per earlier decision) — same JSONModel, two usage points.

## 3. WAU-32 — importer — refined

Convert a data-envelope **instance** (`record`) into AS resources (metadata
objects), via the native AS batch importer + converter (sub-1 report).

- **Schema selection**: `record.Header.MdProfile` (= `clarin.eu:cr1:p_1708423613607`)
  selects the profile/validation schema.
- **Record structure**:
  - `Element` → `{ name, type: "element", value, attributes?: { epoch } }`
  - `Component` → `{ name, type: "component", value: [ …children ] }`
- **Converter walks the tree**: Component → subrecord, Element → field,
  closed enum → controlled value, `skosType` → controlled-value link,
  `Multilingual` → lang_materials.
- **Cardinality validation** against the profile (missing required → reject with
  path in `incompleteFields`, surfaced by the WAU-30 list endpoint).
- **Batch**: ≤ 10 envelope ids per import (matches WAU-30 contract, decision #2).

## 4. Open items carried forward

- Exact AS JSONModel field names for the 277 nodes — covered by
  `WAU-31-jsonmodel-mapping.md` (sub-engineer proposal, Lead Engineer reviewed).

## 5. Locked decisions (Pierre, 2026-08-14)

| # | Decision | Resolution |
|---|----------|------------|
| A1 | Subrecord storage | **Inline JSON blobs** in the root record (no independent tables). Revisit only if `Data` blocks need SQL/Advanced Search in WAU-33+. |
| A2 | SKOS fields | **Dual field** — raw URI + cached `prefLabel` (like AS `name_authority_id`). Full SKOS source deferred to WAU-33. |
| A3 | Multilingual | **Dual-store** — scalar (search/index) + `lang_materials` (i18n). |
| D4 | Pipeline input | **JSON array of ids** sent via HTTP to a pipeline-managed API endpoint (WAU-1); no repo access needed. |
