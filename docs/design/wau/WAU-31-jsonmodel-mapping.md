# WAU-31 — Data Envelope Plugin Skeleton + JSONModel Field-Mapping Proposal

> **Status:** DESIGN/PROPOSAL increment. No controllers/endpoints/UI implemented.  
> **Target repo:** IISH/archivesspace branch `howtodo-plugin-development`  
> **Profile:** `clarin.eu:cr1:p_1708423613607` (Stalling Data Envelope, 277 nodes = 72 Components + 205 Elements)

---

## 1. Plugin Skeleton Layout

Following the `hello_world` plugin pattern, the Data Envelope plugin is named `data_envelope` and sits under `plugins/data_envelope/`.

```
plugins/data_envelope/
├── config.yml                          # Registration: menu entry + parent associations
├── README.md                           # Plugin overview & install notes
│
├── migrations/
│   └── 001_data_envelope_schema.rb     # Sequel migration for data_envelope + child tables
│
├── schemas/
│   ├── data_envelope.rb                # Root JSONModel schema (standalone record)
│   ├── resource_ext.rb                 # Extends Resource with nested data_envelope array
│   ├── accession_ext.rb                # Extends Accession (optional, for completeness)
│   └── data_envelope_subrecords/      # (optional dir) if we split subrecord schemas
│       ├── basic_information.rb
│       ├── contact_details.rb
│       └── ... etc
│
├── backend/
│   ├── model/
│   │   ├── data_envelope.rb            # Sequel model for root record
│   │   ├── mixins/
│   │   │   └── data_envelopes.rb       # def_nested_record for Resource/Accession
│   │   └── resource.rb                 # `Resource.include(DataEnvelopes)`
│   │
│   └── controllers/
│       └── data_envelope.rb            # CRUD endpoints (placeholder — WAU-31 only declares)
│
├── frontend/
│   ├── locales/
│   │   └── en.yml                      # i18n labels for 277 fields
│   ├── controllers/
│   │   └── data_envelope_controller.rb # Frontend routes (placeholder)
│   ├── views/
│   │   └── data_envelope/
│   │       ├── _template.html.erb      # JS template for nested subrecords
│   │       └── index.html.erb          # Standalone list view (placeholder)
│   └── assets/
│       └── (images, JS helpers for SKOS autocomplete)
│
└── indexer/
    └── data_envelope_indexer.rb        # PUI indexing rules (placeholder)
```

### 1.1 `config.yml` (registration)

```yaml
system_menu_controller: data_envelope

parents:
  resource:
    name: data_envelopes
    cardinality: zero_to_many
  accession:
    name: data_envelopes
    cardinality: zero_to_many
```

- Standalone record gets its own left-nav menu item (similar to Assessments).
- Also nests on **Resource** and **Accession** as `zero_to_many` (per prior decision: DataEnvelope exists both standalone and nested).

### 1.2 Migration (`001_data_envelope_schema.rb`)

One root table `data_envelope` + foreign-key columns for `resource_id` / `accession_id` when nested.
All repeatable subrecords are **inline JSON blobs** stored in the root record (AS convention for subrecords on custom records), unless we need independent querying.

> **🔒 LOCKED (Pierre, 2026-08-14) — A1:** Keep all repeatable subrecords as **inline JSON blobs** in the root record (no independent tables). Revisit only if `Data` blocks need SQL/Advanced Search in WAU-33+.

Migration skeleton:

```ruby
Sequel.migration do
  up do
    create_table(:data_envelope) do
      primary_key :id
      Integer :lock_version, :default => 0, :null => false
      Integer :json_schema_version, :null => false
      Integer :repo_id, :null => false
      Integer :resource_id, :null => true
      Integer :accession_id, :null => true

      # Top-level scalar fields extracted for indexing
      String :institute, :null => false
      String :data_envelope_id, :null => false   # maps Element "ID"
      String :parent_uri, :null => true          # skosType controlled link
      String :status, :null => false            # enum: under_construction | publish

      # All subrecord data as JSON blob
      Mediumtext :subrecords_json, :null => true

      apply_mtime_columns
    end

    alter_table(:data_envelope) do
      add_foreign_key([:repo_id], :repository, :key => :id)
      add_foreign_key([:resource_id], :resource, :key => :id)
      add_foreign_key([:accession_id], :accession, :key => :id)
      add_index [:institute]
      add_index [:status]
    end
  end

  down do
    drop_table(:data_envelope)
  end
end
```

---

## 2. Record / Subrecord Tree

We define **1 root JSONModel** (`:data_envelope`) that contains the 10 top-level children inline.
Each **Component** maps to a **nested JSONModel subrecord type** (all defined within the same schema file for proposal simplicity, but can be split later).

### 2.1 Top-Level Structure

```
DataEnvelope (root record)
├── institute            [enum, required]
├── data_envelope_id     [string, required]   ← Element name "ID"
├── parent               [controlled-value/SKOS, optional]
├── status               [enum, required, readonly system-managed]
│
├── basic_information    [subrecord, required]
├── basic_metadata       [subrecord, required]
├── data                 [subrecord array, required, repeatable]
├── uses                 [subrecord, required]
├── human_perspective    [subrecord, required]
└── ddb                  [subrecord, optional]
```

### 2.2 Subrecord Breakdown (all 72 Components)

| # | Component Path | Cardinality | AS Subrecord Name | Parent |
|---|----------------|-------------|-------------------|--------|
| 1 | `DataEnvelope` | 1..1 | `data_envelope` | root |
| 2 | `BasicInformation` | 1..1 | `basic_information` | data_envelope |
| 3 | `ContactDetails` | 1..unbounded | `contact_detail` | basic_information |
| 4 | `Dates` (under BasicInfo) | 1..1 | `basic_info_date` | basic_information |
| 5 | `authorDataEnvelope` | 1..unbounded | `author_data_envelope` | basic_information |
| 6 | `feedbackElaboration` (BasicInfo) | 1..1 | `feedback_elaboration` | basic_information |
| 7 | `BasicMetadata` | 1..1 | `basic_metadata` | data_envelope |
| 8 | `Snapshot` | 1..1 | `snapshot` | basic_metadata |
| 9 | `TemporalCoverage` | 1..unbounded | `temporal_coverage` | snapshot |
| 10 | `Dates` (under BasicMetadata) | 1..1 | `metadata_date` | basic_metadata |
| 11 | `CreatorsContributors` | 1..1 | `creators_contributors` | basic_metadata |
| 12 | `publishingOrganisation` | 1..unbounded | `publishing_organisation` | creators_contributors |
| 13 | `Creators` | 1..unbounded | `creator` | creators_contributors |
| 14 | `contributors` | 1..unbounded | `contributor` | creators_contributors |
| 15 | `funding` | 1..unbounded | `funding` | creators_contributors |
| 16 | `distribution` | 1..1 | `distribution` | basic_metadata |
| 17 | `download` | 1..unbounded | `download` | distribution |
| 18 | `citation` | 1..1 | `citation` | distribution |
| 19 | `accessLicenses` | 1..unbounded | `access_license` | basic_metadata |
| 20 | `licensingInformation` | 1..unbounded | `licensing_information` | access_license |
| 21 | `access` | 1..1 | `access` | access_license |
| 22 | `accessRestricted` | 1..1 | `access_restricted` | access |
| 23 | `versionMaintenance` | 1..1 | `version_maintenance` | basic_metadata |
| 24 | `version` | 1..1 | `version_info` | version_maintenance |
| 25 | `maintenance` | 1..1 | `maintenance` | version_maintenance |
| 26 | `maintenancePlan` | 1..1 | `maintenance_plan` | version_maintenance |
| 27 | `nextUpdate` | 1..1 | `next_update` | version_maintenance |
| 28 | `feedbackElaboration` (BasicMetadata) | 1..unbounded | `feedback_elaboration_bm` | basic_metadata |
| 29 | `Data` | 1..unbounded | `data_block` | data_envelope |
| 30 | `DataResourceDescription` | 1..1 | `data_resource_description` | data_block |
| 31 | `dataSubjects` | 1..1 | `data_subjects` | data_resource_description |
| 32 | `dataModality` | 1..1 | `data_modality` | data_resource_description |
| 33 | `descriptiveStatistics` | 1..1 | `descriptive_statistics` | data_resource_description |
| 34 | `dataFields` | 1..unbounded | `data_fields` | data_block |
| 35 | `dataField` | 1..unbounded | `data_field` | data_fields |
| 36 | `usedVocabularies` | 1..1 | `used_vocabulary` | data_field |
| 37 | `dataExamples` | 1..1 | `data_examples` | data_block |
| 38 | `typicalExample` | 1..1 | `typical_example` | data_examples |
| 39 | `atypicalExample` | 1..1 | `atypical_example` | data_examples |
| 40 | `errors` | 1..1 | `error_block` | data_block |
| 41 | `externalResources` | 1..1 | `external_resources` | data_block |
| 42 | `annotations` | 1..1 | `annotations` | data_block |
| 43 | `annotationCharacteristics` | 1..unbounded | `annotation_characteristics` | annotations |
| 44 | `socialImpact` | 1..1 | `social_impact` | data_block |
| 45 | `safety` | 1..1 | `safety` | social_impact |
| 46 | `confidentiality` | 1..1 | `confidentiality` | social_impact |
| 47 | `biases` | 1..1 | `biases` | social_impact |
| 48 | `sensAttributes` | 1..1 | `sensitive_attributes` | biases |
| 49 | `ethicalReview` | 1..1 | `ethical_review` | social_impact |
| 50 | `reviewContact` | 1..1 | `review_contact` | ethical_review |
| 51 | `dataProvenance` | 1..unbounded | `data_provenance` | data_block |
| 52 | `digitisation` | 1..1 | `digitisation` | data_block |
| 53 | `feedbackElaboration` (Data) | 1..1 | `feedback_elaboration_data` | data_block |
| 54 | `Uses` | 1..1 | `uses` | data_envelope |
| 55 | `Use` | 1..unbounded | `use_case` | uses |
| 56 | `LinksToRelatedItems` | 1..1 | `links_to_related_items` | use_case |
| 57 | `SuitableUseCase` | 1..unbounded | `suitable_use_case` | use_case |
| 58 | `UnsuitableUseCase` | 1..1 | `unsuitable_use_case` | use_case |
| 59 | `UseWithOtherData` | 1..1 | `use_with_other_data` | use_case |
| 60 | `UseInMLOrAISystems` | 1..1 | `use_in_ml_ai` | use_case |
| 61 | `Sampling` | 1..1 | `sampling` | uses |
| 62 | `feedbackElaboration` (Uses) | 1..1 | `feedback_elaboration_uses` | uses |
| 63 | `HumanPerspective` | 1..1 | `human_perspective` | data_envelope |
| 64 | `HumanAnnotators` | 1..1 | `human_annotators` | human_perspective |
| 65 | `AnnotationType` | 1..unbounded | `annotation_type` | human_annotators |
| 66 | `Creators` (under HumanPerspective) | 1..1 | `creators_hp` | human_perspective |
| 67 | `feedbackElaboration` (HP) | 1..1 | `feedback_elaboration_hp` | human_perspective |
| 68 | `DDB` | 0..1 | `ddb` | data_envelope |
| 69 | `Link` | 0..unbounded | `ddb_link` | ddb |
| 70 | `Note` | 0..unbounded | `ddb_note` | ddb |
| 71 | `Contact` | 0..unbounded | `ddb_contact` | ddb |
| 72 | `Directory` | 0..unbounded | `ddb_directory` | ddb |

**Note:** Where the same component name appears under multiple parents (e.g. `Dates`, `Creators`, `feedbackElaboration`), we give each a **unique AS subrecord name** to avoid ambiguity in the JSONModel schema.

---

## 3. Complete Field-Mapping Table (All 277 Nodes)

### Legend
- **Node Type:** Component (C) or Element (E)
- **AS Record:** Which JSONModel subrecord type owns this field
- **AS Field Name:** Proposed snake_case name in AS JSONModel
- **AS Type:** JSONModel type + constraint
- **Enum / CV:** Controlled vocabulary handling (see §4)
- **Req:** Required (1..1) vs Optional (0..1 or 0..unbounded)
- **Rpt:** Repeatable (unbounded) vs Single (1)
- **Flags:** Ambiguities or special handling

---

### 3.1 Top-Level Fields (DataEnvelope root)

| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 0 | `DataEnvelope` | C | `data_envelope` | *(root record)* | — | — | R | S | Root container |
| 1 | `institute` | E | `data_envelope` | `institute` | string, maxLength 50 | **enum** `de_institute` | R | S | — |
| 2 | `ID` | E | `data_envelope` | `data_envelope_id` | string, maxLength 255 | — | R | S | Renamed to avoid AS reserved `id` |
| 3 | `parent` | E | `data_envelope` | `parent_uri` | string, maxLength 2048 | **SKOS controlled link** | O | S | `class:skosType`, `autoCompleteURI` |
| 4 | `status` | E | `data_envelope` | `status` | string, maxLength 50 | **enum** `de_status` | R | S | `class:status`, `readonly` → system-managed |

---

### 3.2 BasicInformation (1 Component + 4 sub-Components)

#### BasicInformation root
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 5 | `BasicInformation` | C | `basic_information` | *(subrecord container)* | — | — | R | S | — |
| 6 | `title` | E | `basic_information` | `title` | string, maxLength 65000 | — | R | S | `Multilingual:true` → maps to `lang_materials` |

#### ContactDetails (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 7 | `ContactDetails` | C | `contact_detail` | *(container)* | — | — | R | **Y** | — |
| 8 | `name` | E | `contact_detail` | `name` | string, maxLength 65000 | — | R | S | — |
| 9 | `orcidID` | E | `contact_detail` | `orcid_id` | string, maxLength 50 | — | O | S | — |
| 10 | `roleInProject` | E | `contact_detail` | `role_in_project` | string, maxLength 100 | **enum** `de_role_in_project` | O | **Y** | — |
| 11 | `email` | E | `contact_detail` | `email` | string, maxLength 255 | — | R | S | — |

#### Dates (under BasicInfo)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 12 | `Dates` (BasicInfo) | C | `basic_info_date` | *(container)* | — | — | R | S | — |
| 13 | `creationDateFrom` | E | `basic_info_date` | `creation_date_from` | date | — | R | S | — |
| 14 | `creationDateTo` | E | `basic_info_date` | `creation_date_to` | date | — | O | S | — |
| 15 | `publicationDate` | E | `basic_info_date` | `publication_date` | date | — | O | S | — |

#### authorDataEnvelope (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 16 | `authorDataEnvelope` | C | `author_data_envelope` | *(container)* | — | — | R | **Y** | — |
| 17 | `name` | E | `author_data_envelope` | `name` | string, maxLength 65000 | — | R | S | — |
| 18 | `orcidID` | E | `author_data_envelope` | `orcid_id` | string, maxLength 50 | — | O | S | — |
| 19 | `email` | E | `author_data_envelope` | `email` | string, maxLength 255 | — | O | S | — |

#### feedbackElaboration (BasicInfo)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 20 | `feedbackElaboration` (BI) | C | `feedback_elaboration` | *(container)* | — | — | R | S | — |
| 21 | `feedbackSectionOne` | E | `feedback_elaboration` | `feedback_section_one` | string, maxLength 65000 | — | O | **Y** | — |

---

### 3.3 BasicMetadata (1 Component, 7 sub-Components)

#### Snapshot
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 22 | `BasicMetadata` | C | `basic_metadata` | *(subrecord container)* | — | — | R | S | — |
| 23 | `Snapshot` | C | `snapshot` | *(container)* | — | — | R | S | — |
| 24 | `title` | E | `snapshot` | `title` | string, maxLength 65000 | — | R | S | `Multilingual:true` → `lang_materials` |
| 25 | `version` | E | `snapshot` | `version` | decimal (string stored) | — | R | S | — |
| 26 | `description` | E | `snapshot` | `description` | string, maxLength 65000 | — | R | S | — |
| 27 | `genre` | E | `snapshot` | `genre` | string, maxLength 255 | **SKOS controlled link** | O | **Y** | `class:skosType` |
| 28 | `genreOther` | E | `snapshot` | `genre_other` | string, maxLength 255 | — | O | **Y** | Free-text fallback when genre=Other |
| 29 | `topic` | E | `snapshot` | `topic` | string, maxLength 255 | **SKOS controlled link** | R | **Y** | `class:skosType` |
| 30 | `topicOther` | E | `snapshot` | `topic_other` | string, maxLength 255 | — | O | **Y** | Free-text fallback |
| 31 | `languages` | E | `snapshot` | `languages` | string, maxLength 50 | **SKOS controlled link** | R | **Y** | `class:skosType` |
| 32 | `languageOther` | E | `snapshot` | `language_other` | string, maxLength 255 | — | O | **Y** | Free-text fallback |
| 33 | `GeographicalCoverage` | E | `snapshot` | `geographical_coverage` | string, maxLength 255 | — | R | S | — |
| 34 | `GeographicalCoverageOther` | E | `snapshot` | `geographical_coverage_other` | string, maxLength 255 | — | O | **Y** | — |
| 35 | `TemporalCoverage` | C | `temporal_coverage` | *(container)* | — | — | R | **Y** | — |
| 36 | `yearFrom` | E | `temporal_coverage` | `year_from` | string, maxLength 10 | — | O | S | `gYear` stored as YYYY string |
| 37 | `yearTo` | E | `temporal_coverage` | `year_to` | string, maxLength 10 | — | O | S | `gYear` stored as YYYY string |
| 38 | `year` | E | `temporal_coverage` | `year` | string, maxLength 255 | — | O | **Y** | Free-form year label |
| 39 | `additionalNotes` | E | `temporal_coverage` | `additional_notes` | string, maxLength 65000 | — | O | S | — |

#### Dates (under BasicMetadata)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 40 | `Dates` (BM) | C | `metadata_date` | *(container)* | — | — | R | S | — |
| 41 | `dateFrom` | E | `metadata_date` | `date_from` | date | — | O | S | — |
| 42 | `dateTo` | E | `metadata_date` | `date_to` | date | — | O | S | — |
| 43 | `datasetPublicationDate` | E | `metadata_date` | `dataset_publication_date` | date | — | O | S | — |

#### CreatorsContributors
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 44 | `CreatorsContributors` | C | `creators_contributors` | *(container)* | — | — | R | S | — |

##### publishingOrganisation (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 45 | `publishingOrganisation` | C | `publishing_organisation` | *(container)* | — | — | R | **Y** | — |
| 46 | `Name` | E | `publishing_organisation` | `name` | string, maxLength 65000 | — | O | S | — |
| 47 | `ROR` | E | `publishing_organisation` | `ror` | string, maxLength 50 | — | O | S | — |
| 48 | `type` | E | `publishing_organisation` | `organisation_type` | string, maxLength 100 | **enum** `de_org_type` | O | S | — |
| 49 | `other` | E | `publishing_organisation` | `other_type` | string, maxLength 255 | — | O | S | — |

##### Creators (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 50 | `Creators` | C | `creator` | *(container)* | — | — | R | **Y** | — |
| 51 | `Name` | E | `creator` | `name` | string, maxLength 65000 | — | R | S | — |
| 52 | `ORCID` | E | `creator` | `orcid` | string, maxLength 50 | — | O | S | — |
| 53 | `Organisation` | E | `creator` | `organisation` | string, maxLength 65000 | — | O | S | — |
| 54 | `ROR` | E | `creator` | `ror` | string, maxLength 2048 | — | O | S | `anyURI` → string for storage |
| 55 | `Role` | E | `creator` | `role` | string, maxLength 100 | **enum** `de_creator_role` | O | **Y** | — |
| 56 | `email` | E | `creator` | `email` | string, maxLength 255 | — | O | S | — |

##### contributors (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 57 | `contributors` | C | `contributor` | *(container)* | — | — | R | **Y** | — |
| 58 | `name` | E | `contributor` | `name` | string, maxLength 65000 | — | O | S | — |
| 59 | `organisation` | E | `contributor` | `organisation` | string, maxLength 65000 | — | O | S | — |
| 60 | `descriptionContribution` | E | `contributor` | `description_contribution` | string, maxLength 65000 | — | O | S | — |

##### funding (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 61 | `funding` | C | `funding` | *(container)* | — | — | R | **Y** | — |
| 62 | `name` | E | `funding` | `name` | string, maxLength 65000 | — | O | S | — |
| 63 | `ROR` | E | `funding` | `ror` | string, maxLength 2048 | — | O | S | `anyURI` → string |
| 64 | `summary` | E | `funding` | `summary` | string, maxLength 65000 | — | O | S | — |
| 65 | `link` | E | `funding` | `link` | string, maxLength 2048 | — | O | S | `anyURI` → string |

#### distribution
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 66 | `distribution` | C | `distribution` | *(container)* | — | — | R | S | — |
| 67 | `datasetlink` | E | `distribution` | `dataset_link` | string, maxLength 2048 | — | O | **Y** | `anyURI` → string |
| 68 | `repository` | E | `distribution` | `repository` | string, maxLength 2048 | — | O | **Y** | `anyURI` → string |

##### download (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 69 | `download` | C | `download` | *(container)* | — | — | R | **Y** | — |
| 70 | `link` | E | `download` | `link` | string, maxLength 2048 | — | O | **Y** | `anyURI` → string |
| 71 | `filetype` | E | `download` | `filetype` | string, maxLength 255 | — | O | S | — |
| 72 | `filesize` | E | `download` | `filesize` | integer | — | O | S | — |

##### citation
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 73 | `citation` | C | `citation` | *(container)* | — | — | R | S | — |
| 74 | `citationInformation` | E | `citation` | `citation_information` | string, maxLength 65000 | — | O | S | `Multilingual:true` → `lang_materials` |

#### accessLicenses (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 75 | `accessLicenses` | C | `access_license` | *(container)* | — | — | R | **Y** | — |

##### licensingInformation (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 76 | `licensingInformation` | C | `licensing_information` | *(container)* | — | — | R | **Y** | — |
| 77 | `identifier` | E | `licensing_information` | `identifier` | string, maxLength 255 | — | O | S | — |
| 78 | `url` | E | `licensing_information` | `url` | string, maxLength 2048 | — | O | S | `anyURI` → string |

##### access
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 79 | `access` | C | `access` | *(container)* | — | — | R | S | — |
| 80 | `accessLevel` | E | `access` | `access_level` | string, maxLength 100 | **enum** `de_access_level` | O | S | — |

###### accessRestricted
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 81 | `accessRestricted` | C | `access_restricted` | *(container)* | — | — | R | S | — |
| 82 | `description` | E | `access_restricted` | `description` | string, maxLength 65000 | — | O | S | — |
| 83 | `url` | E | `access_restricted` | `url` | string, maxLength 2048 | — | O | S | String, not URI (profile says string) |
| 84 | `contactEmail` | E | `access_restricted` | `contact_email` | string, maxLength 255 | — | O | S | — |
| 85 | `accessPrerequisites` | E | `access_restricted` | `access_prerequisites` | string, maxLength 65000 | — | O | S | — |

#### versionMaintenance
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 86 | `versionMaintenance` | C | `version_maintenance` | *(container)* | — | — | R | S | — |

##### version
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 87 | `version` | C | `version_info` | *(container)* | — | — | R | S | — |
| 88 | `currentVersion` | E | `version_info` | `current_version` | decimal (string) | — | R | S | — |
| 89 | `lastUpdated` | E | `version_info` | `last_updated` | date | — | O | S | — |
| 90 | `releaseDate` | E | `version_info` | `release_date` | date | — | O | S | — |

##### maintenance
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 91 | `maintenance` | C | `maintenance` | *(container)* | — | — | R | S | — |
| 92 | `maintenanceStatus` | E | `maintenance` | `maintenance_status` | string, maxLength 100 | **enum** `de_maintenance_status` | O | S | — |

##### maintenancePlan
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 93 | `maintenancePlan` | C | `maintenance_plan` | *(container)* | — | — | R | S | — |
| 94 | `updates` | E | `maintenance_plan` | `updates` | string, maxLength 65000 | — | O | S | — |
| 95 | `feedback` | E | `maintenance_plan` | `feedback` | string, maxLength 65000 | — | O | S | — |

##### nextUpdate
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 96 | `nextUpdate` | C | `next_update` | *(container)* | — | — | R | S | — |
| 97 | `versionAffected` | E | `next_update` | `version_affected` | decimal (string) | — | O | S | — |
| 98 | `nextUpdate` | E | `next_update` | `next_update_date` | date | — | O | S | Renamed to avoid collision with subrecord name |
| 99 | `nextVersion` | E | `next_update` | `next_version` | decimal (string) | — | O | S | — |

#### feedbackElaboration (BasicMetadata, repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 100 | `feedbackElaboration` (BM) | C | `feedback_elaboration_bm` | *(container)* | — | — | R | **Y** | — |
| 101 | `feedbackSectionTwo` | E | `feedback_elaboration_bm` | `feedback_section_two` | string, maxLength 65000 | — | O | **Y** | — |

---

### 3.4 Data (repeatable, 1..unbounded)

#### Data root
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 102 | `Data` | C | `data_block` | *(container)* | — | — | R | **Y** | — |

##### DataResourceDescription
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 103 | `DataResourceDescription` | C | `data_resource_description` | *(container)* | — | — | R | S | — |
| 104 | `nameOfResource` | E | `data_resource_description` | `name_of_resource` | string, maxLength 65000 | — | R | S | — |
| 105 | `Description` | E | `data_resource_description` | `description` | string, maxLength 65000 | — | R | S | — |
| 106 | `path` | E | `data_resource_description` | `path` | string, maxLength 2048 | — | O | S | `anyURI` → string |
| 107 | `format` | E | `data_resource_description` | `format` | string, maxLength 255 | — | O | S | — |
| 108 | `size` | E | `data_resource_description` | `size` | integer | — | O | S | — |
| 109 | `date` | E | `data_resource_description` | `date` | date | — | O | S | — |
| 110 | `language` | E | `data_resource_description` | `language` | string, maxLength 100 | — | O | S | — |
| 111 | `encoding` | E | `data_resource_description` | `encoding` | string, maxLength 100 | — | O | S | — |

###### dataSubjects
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 112 | `dataSubjects` | C | `data_subjects` | *(container)* | — | — | R | S | — |
| 113 | `Subjects` | E | `data_subjects` | `subjects` | string, maxLength 100 | **enum** `de_data_subjects` | O | **Y** | — |
| 114 | `other` | E | `data_subjects` | `other` | string, maxLength 255 | — | O | S | — |

###### dataModality
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 115 | `dataModality` | C | `data_modality` | *(container)* | — | — | R | S | — |
| 116 | `modality` | E | `data_modality` | `modality` | string, maxLength 100 | **enum** `de_data_modality` | O | **Y** | — |
| 117 | `other` | E | `data_modality` | `other` | string, maxLength 255 | — | O | S | — |

###### descriptiveStatistics
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 118 | `descriptiveStatistics` | C | `descriptive_statistics` | *(container)* | — | — | R | S | — |
| 119 | `statistics` | E | `descriptive_statistics` | `statistics` | string, maxLength 65000 | — | O | S | — |

##### dataFields (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 120 | `dataFields` | C | `data_fields` | *(container)* | — | — | R | **Y** | — |

###### dataField (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 121 | `dataField` | C | `data_field` | *(container)* | — | — | R | **Y** | — |
| 122 | `dataFieldName` | E | `data_field` | `data_field_name` | string, maxLength 255 | — | O | S | — |
| 123 | `dataFieldType` | E | `data_field` | `data_field_type` | string, maxLength 255 | **SKOS controlled link** | O | S | `class:skosType` |
| 124 | `descriptionField` | E | `data_field` | `description_field` | string, maxLength 65000 | — | O | S | — |
| 125 | `sensitivity` | E | `data_field` | `sensitivity` | string, maxLength 255 | — | O | S | — |
| 126 | `notableFeatures` | E | `data_field` | `notable_features` | string, maxLength 65000 | — | O | S | — |

####### usedVocabularies
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 127 | `usedVocabularies` | C | `used_vocabulary` | *(container)* | — | — | R | S | — |
| 128 | `vocabulary` | E | `used_vocabulary` | `vocabulary` | string, maxLength 255 | — | O | S | — |
| 129 | `vocabularyLink` | E | `used_vocabulary` | `vocabulary_link` | string, maxLength 2048 | — | O | S | `anyURI` → string |

##### dataExamples
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 130 | `dataExamples` | C | `data_examples` | *(container)* | — | — | R | S | — |

###### typicalExample
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 131 | `typicalExample` | C | `typical_example` | *(container)* | — | — | R | S | — |
| 132 | `description` | E | `typical_example` | `description` | string, maxLength 65000 | — | O | S | — |
| 133 | `link` | E | `typical_example` | `link` | string, maxLength 2048 | — | O | S | `anyURI` → string |

###### atypicalExample
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 134 | `atypicalExample` | C | `atypical_example` | *(container)* | — | — | R | S | — |
| 135 | `atypdescription` | E | `atypical_example` | `atypical_description` | string, maxLength 65000 | — | O | S | — |
| 136 | `atyplink` | E | `atypical_example` | `atypical_link` | string, maxLength 2048 | — | O | S | `anyURI` → string |

##### errors
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 137 | `errors` | C | `error_block` | *(container)* | — | — | R | S | — |
| 138 | `errordescription` | E | `error_block` | `error_description` | string, maxLength 65000 | — | O | S | — |

##### externalResources
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 139 | `externalResources` | C | `external_resources` | *(container)* | — | — | R | S | — |
| 140 | `resources` | E | `external_resources` | `resources` | string, maxLength 10 | **enum** `de_yes_no` | O | S | — |
| 141 | `extResources` | E | `external_resources` | `external_resources` | string, maxLength 65000 | — | O | **Y** | — |

##### annotations
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 142 | `annotations` | C | `annotations` | *(container)* | — | — | R | S | — |

###### annotationCharacteristics (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 143 | `annotationCharacteristics` | C | `annotation_characteristics` | *(container)* | — | — | R | **Y** | — |
| 144 | `annotationWorkforceType` | E | `annotation_characteristics` | `annotation_workforce_type` | string, maxLength 100 | **enum** `de_annotation_workforce` | O | S | — |
| 145 | `others` | E | `annotation_characteristics` | `others` | string, maxLength 255 | — | O | S | — |
| 146 | `description` | E | `annotation_characteristics` | `description` | string, maxLength 65000 | — | O | S | — |
| 147 | `totalAnnotations` | E | `annotation_characteristics` | `total_annotations` | integer | — | O | S | — |
| 148 | `totalTokens` | E | `annotation_characteristics` | `total_tokens` | string, maxLength 255 | — | O | S | Profile says string, not int |
| 149 | `avgTokensAnnotations` | E | `annotation_characteristics` | `avg_tokens_annotations` | string, maxLength 255 | — | O | S | Profile says string |
| 150 | `metric` | E | `annotation_characteristics` | `metric` | string, maxLength 255 | — | O | S | — |

##### socialImpact
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 151 | `socialImpact` | C | `social_impact` | *(container)* | — | — | R | S | — |

###### safety
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 152 | `safety` | C | `safety` | *(container)* | — | — | R | S | — |
| 153 | `disclaimer` | E | `safety` | `disclaimer` | string, maxLength 20 | **enum** `de_yes_no_not_sure` | R | S | — |
| 154 | `specify` | E | `safety` | `specify` | string, maxLength 65000 | — | O | S | — |

###### confidentiality
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 155 | `confidentiality` | C | `confidentiality` | *(container)* | — | — | R | S | — |
| 156 | `confidentialityBin` | E | `confidentiality` | `confidentiality` | string, maxLength 10 | **enum** `de_yes_no` | R | S | — |
| 157 | `specify` | E | `confidentiality` | `specify` | string, maxLength 65000 | — | O | S | — |

###### biases
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 158 | `biases` | C | `biases` | *(container)* | — | — | R | S | — |
| 159 | `knownBiases` | E | `biases` | `known_biases` | string, maxLength 65000 | — | O | S | — |
| 160 | `stepsToReduceBias` | E | `biases` | `steps_to_reduce_bias` | string, maxLength 65000 | — | O | S | — |

####### sensAttributes
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 161 | `sensAttributes` | C | `sensitive_attributes` | *(container)* | — | — | R | S | — |
| 162 | `sensitiveAttribute` | E | `sensitive_attributes` | `sensitive_attribute` | string, maxLength 100 | **enum** `de_sensitive_attributes` | R | S | — |
| 163 | `specify` | E | `sensitive_attributes` | `specify` | string, maxLength 65000 | — | O | S | — |
| 164 | `unintentionalAttribute` | E | `sensitive_attributes` | `unintentional_attribute` | string, maxLength 65000 | — | O | S | — |

###### ethicalReview
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 165 | `ethicalReview` | C | `ethical_review` | *(container)* | — | — | R | S | — |
| 166 | `review` | E | `ethical_review` | `review` | string, maxLength 10 | **enum** `de_yes_no` | R | S | — |
| 167 | `description` | E | `ethical_review` | `description` | string, maxLength 65000 | — | O | S | — |
| 168 | `outcomes` | E | `ethical_review` | `outcomes` | string, maxLength 65000 | — | O | S | — |
| 169 | `link` | E | `ethical_review` | `link` | string, maxLength 2048 | — | O | S | `anyURI` → string |

####### reviewContact
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 170 | `reviewContact` | C | `review_contact` | *(container)* | — | — | R | S | — |
| 171 | `name` | E | `review_contact` | `name` | string, maxLength 65000 | — | O | S | — |
| 172 | `affiliation` | E | `review_contact` | `affiliation` | string, maxLength 65000 | — | O | S | — |
| 173 | `contact` | E | `review_contact` | `contact` | string, maxLength 255 | — | O | S | Generic contact string |

##### dataProvenance (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 174 | `dataProvenance` | C | `data_provenance` | *(container)* | — | — | R | **Y** | — |
| 175 | `Name` | E | `data_provenance` | `name` | string, maxLength 65000 | — | R | S | — |
| 176 | `path` | E | `data_provenance` | `path` | string, maxLength 2048 | — | O | S | `anyURI` → string |
| 177 | `description` | E | `data_provenance` | `description` | string, maxLength 65000 | — | R | S | — |
| 178 | `creatorName` | E | `data_provenance` | `creator_name` | string, maxLength 65000 | — | O | **Y** | — |
| 179 | `creatorOrganisation` | E | `data_provenance` | `creator_organisation` | string, maxLength 65000 | — | O | **Y** | — |
| 180 | `yearPublication` | E | `data_provenance` | `year_publication` | string, maxLength 10 | — | O | S | `gYear` → YYYY string |
| 181 | `language` | E | `data_provenance` | `language` | string, maxLength 100 | — | O | S | — |
| 182 | `temporalScope` | E | `data_provenance` | `temporal_scope` | string, maxLength 65000 | — | O | S | — |
| 183 | `geographicalScope` | E | `data_provenance` | `geographical_scope` | string, maxLength 65000 | — | O | S | — |
| 184 | `notableFeatures` | E | `data_provenance` | `notable_features` | string, maxLength 65000 | — | O | S | — |
| 185 | `datasheetEnvelope` | E | `data_provenance` | `datasheet_envelope` | string, maxLength 2048 | — | O | S | `anyURI` → string |
| 186 | `dataSelection` | E | `data_provenance` | `data_selection` | string, maxLength 65000 | — | O | S | — |

##### digitisation
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 187 | `digitisation` | C | `digitisation` | *(container)* | — | — | R | S | — |
| 188 | `digitalisationPipeline` | E | `digitisation` | `digitalisation_pipeline` | string, maxLength 65000 | — | O | S | — |

##### feedbackElaboration (Data)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 189 | `feedbackElaboration` (Data) | C | `feedback_elaboration_data` | *(container)* | — | — | R | S | — |
| 190 | `feedbackSectionThree` | E | `feedback_elaboration_data` | `feedback_section_three` | string, maxLength 65000 | — | O | **Y** | — |

---

### 3.5 Uses (1 Component, 5 sub-Components)

| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 191 | `Uses` | C | `uses` | *(container)* | — | — | R | S | — |
| 192 | `purposes` | E | `uses` | `purposes` | string, maxLength 100 | **enum** `de_purposes` | O | **Y** | — |
| 193 | `other` | E | `uses` | `other` | string, maxLength 255 | — | O | S | — |
| 194 | `domains` | E | `uses` | `domains` | string, maxLength 255 | **SKOS controlled link** | O | **Y** | `class:skosType` |
| 195 | `motivation` | E | `uses` | `motivation` | string, maxLength 65000 | — | O | S | — |

#### Use (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 196 | `Use` | C | `use_case` | *(container)* | — | — | R | **Y** | — |
| 197 | `datasetUse` | E | `use_case` | `dataset_use` | string, maxLength 100 | **enum** `de_dataset_use` | O | S | — |
| 198 | `datasetUseSpecify` | E | `use_case` | `dataset_use_specify` | string, maxLength 255 | — | O | S | — |

##### LinksToRelatedItems
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 199 | `LinksToRelatedItems` | C | `links_to_related_items` | *(container)* | — | — | R | S | — |
| 200 | `publications` | E | `links_to_related_items` | `publications` | string, maxLength 2048 | — | O | **Y** | `anyURI` → string |
| 201 | `relatedDatasets` | E | `links_to_related_items` | `related_datasets` | string, maxLength 2048 | — | O | **Y** | `anyURI` → string |
| 202 | `modelTrainedByDataset` | E | `links_to_related_items` | `model_trained_by_dataset` | string, maxLength 2048 | — | O | **Y** | `anyURI` → string |

##### SuitableUseCase (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 203 | `SuitableUseCase` | C | `suitable_use_case` | *(container)* | — | — | R | **Y** | — |
| 204 | `suitableUseCase` | E | `suitable_use_case` | `suitable_use_case` | string, maxLength 65000 | — | O | S | — |
| 205 | `additionalNotes` | E | `suitable_use_case` | `additional_notes` | string, maxLength 65000 | — | O | S | — |

##### UnsuitableUseCase
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 206 | `UnsuitableUseCase` | C | `unsuitable_use_case` | *(container)* | — | — | R | S | — |
| 207 | `unsuitableUseCase` | E | `unsuitable_use_case` | `unsuitable_use_case` | string, maxLength 65000 | — | O | S | — |
| 208 | `additionalNotes` | E | `unsuitable_use_case` | `additional_notes` | string, maxLength 65000 | — | O | S | — |

#### UseWithOtherData
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 209 | `UseWithOtherData` | C | `use_with_other_data` | *(container)* | — | — | R | S | — |
| 210 | `SafetyLevel` | E | `use_with_other_data` | `safety_level` | string, maxLength 100 | **enum** `de_safety_level` | R | S | — |
| 211 | `safetyLevelOther` | E | `use_with_other_data` | `safety_level_other` | string, maxLength 255 | — | O | S | — |
| 212 | `knownSafeDatasetsDataTypes` | E | `use_with_other_data` | `known_safe_datasets` | string, maxLength 65000 | — | O | S | — |
| 213 | `KnownUnsafeDatasetsDataTypes` | E | `use_with_other_data` | `known_unsafe_datasets` | string, maxLength 65000 | — | O | S | — |

#### UseInMLOrAISystems
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 214 | `UseInMLOrAISystems` | C | `use_in_ml_ai` | *(container)* | — | — | R | S | — |
| 215 | `datasetUses` | E | `use_in_ml_ai` | `dataset_uses` | string, maxLength 100 | **enum** `de_dataset_uses` | O | S | — |
| 216 | `otherDatasetUses` | E | `use_in_ml_ai` | `other_dataset_uses` | string, maxLength 255 | — | O | S | — |
| 217 | `notableFeatures` | E | `use_in_ml_ai` | `notable_features` | string, maxLength 65000 | — | O | S | — |
| 218 | `knownCorrelations` | E | `use_in_ml_ai` | `known_correlations` | string, maxLength 65000 | — | O | S | — |
| 219 | `usageGuidelines` | E | `use_in_ml_ai` | `usage_guidelines` | string, maxLength 65000 | — | O | S | — |
| 220 | `dataSplits` | E | `use_in_ml_ai` | `data_splits` | string, maxLength 65000 | — | O | S | — |

#### Sampling
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 221 | `Sampling` | C | `sampling` | *(container)* | — | — | R | S | — |
| 222 | `safetyLevel` | E | `sampling` | `safety_level` | string, maxLength 100 | **enum** `de_sampling_safety` | O | S | — |
| 223 | `otherSafetyLevel` | E | `sampling` | `other_safety_level` | string, maxLength 255 | — | O | S | — |
| 224 | `acceptableSamplingMethods` | E | `sampling` | `acceptable_sampling_methods` | string, maxLength 100 | **enum** `de_sampling_methods` | O | **Y** | — |
| 225 | `otherAcceptableSamplingMethods` | E | `sampling` | `other_acceptable_sampling_methods` | string, maxLength 255 | — | O | **Y** | — |
| 226 | `bestPractices` | E | `sampling` | `best_practices` | string, maxLength 65000 | — | O | S | — |
| 227 | `risksAndMitigations` | E | `sampling` | `risks_and_mitigations` | string, maxLength 65000 | — | O | **Y** | — |

#### feedbackElaboration (Uses)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 228 | `feedbackElaboration` (Uses) | C | `feedback_elaboration_uses` | *(container)* | — | — | R | S | — |
| 229 | `feedbackSectionFour` | E | `feedback_elaboration_uses` | `feedback_section_four` | string, maxLength 65000 | — | O | **Y** | — |

---

### 3.6 HumanPerspective (1 Component, 3 sub-Components)

| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 230 | `HumanPerspective` | C | `human_perspective` | *(container)* | — | — | R | S | — |

#### HumanAnnotators
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 231 | `HumanAnnotators` | C | `human_annotators` | *(container)* | — | — | R | S | — |
| 232 | `annotatorDescription` | E | `human_annotators` | `annotator_description` | string, maxLength 65000 | — | R | **Y** | — |

##### AnnotationType (repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 233 | `AnnotationType` | C | `annotation_type` | *(container)* | — | — | R | **Y** | — |
| 234 | `taskType` | E | `annotation_type` | `task_type` | string, maxLength 255 | — | O | S | — |
| 235 | `numberOfUniqueAnnotators` | E | `annotation_type` | `number_of_unique_annotators` | integer | — | O | S | — |
| 236 | `avgannotations` | E | `annotation_type` | `avg_annotations` | integer | — | O | S | — |
| 237 | `expertiseOfAnnotators` | E | `annotation_type` | `expertise_of_annotators` | string, maxLength 65000 | — | O | S | — |
| 238 | `descriptionOfAnnotators` | E | `annotation_type` | `description_of_annotators` | string, maxLength 65000 | — | O | S | — |
| 239 | `compensation` | E | `annotation_type` | `compensation` | string, maxLength 65000 | — | O | S | — |
| 240 | `languageDistributionOfAnnotators` | E | `annotation_type` | `language_distribution_of_annotators` | string, maxLength 255 | — | O | **Y** | — |
| 241 | `numLanguageDistrib` | E | `annotation_type` | `num_language_distrib` | string, maxLength 255 | — | O | S | — |
| 242 | `ageDistributionOfAnnotators` | E | `annotation_type` | `age_distribution_of_annotators` | string, maxLength 255 | — | O | S | — |
| 243 | `numAgeDistrib` | E | `annotation_type` | `num_age_distrib` | string, maxLength 255 | — | O | S | — |
| 244 | `geographicDistributionOfAnnotators` | E | `annotation_type` | `geographic_distribution_of_annotators` | string, maxLength 255 | — | O | S | — |
| 245 | `genderDistributionOfAnnotators` | E | `annotation_type` | `gender_distribution_of_annotators` | string, maxLength 255 | — | O | S | — |
| 246 | `socioEconomicDistribOfAnnotators` | E | `annotation_type` | `socio_economic_distrib_of_annotators` | string, maxLength 255 | — | O | S | — |
| 247 | `summaryOfAnnotationInstructions` | E | `annotation_type` | `summary_of_annotation_instructions` | string, maxLength 65000 | — | O | S | — |
| 248 | `annotationPlatforms` | E | `annotation_type` | `annotation_platforms` | string, maxLength 65000 | — | O | S | — |
| 249 | `additionalNotes` | E | `annotation_type` | `additional_notes` | string, maxLength 65000 | — | O | S | — |

#### Creators (under HumanPerspective)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 250 | `Creators` (HP) | C | `creators_hp` | *(container)* | — | — | R | S | — |
| 251 | `creatorPositionality` | E | `creators_hp` | `creator_positionality` | string, maxLength 65000 | — | O | S | — |

#### feedbackElaboration (HumanPerspective)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 252 | `feedbackElaboration` (HP) | C | `feedback_elaboration_hp` | *(container)* | — | — | R | S | — |
| 253 | `feedbackSectionFive` | E | `feedback_elaboration_hp` | `feedback_section_five` | string, maxLength 65000 | — | O | **Y** | — |

---

### 3.7 DDB (optional, 1 Component, 4 sub-Components)

| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 254 | `DDB` | C | `ddb` | *(container)* | — | — | O | S | Optional block (0..1) |
| 255 | `description` | E | `ddb` | `description` | string, maxLength 65000 | — | R | S | `Multilingual:true` → `lang_materials` |
| 256 | `project` | E | `ddb` | `project` | string, maxLength 65000 | — | O | S | `Multilingual:true` → `lang_materials` |
| 257 | `stalling` | E | `ddb` | `stalling` | string, maxLength 255 | — | R | S | — |
| 258 | `level` | E | `ddb` | `level` | string, maxLength 100 | **enum** `de_sensitivity_level` | R | S | — |

#### Link (optional, repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 259 | `Link` | C | `ddb_link` | *(container)* | — | — | O | **Y** | — |
| 260 | `link` | E | `ddb_link` | `link` | string, maxLength 2048 | — | R | S | `anyURI` → string |
| 261 | `type` | E | `ddb_link` | `link_type` | string, maxLength 50 | **enum** `de_link_type` | R | S | — |

#### Note (optional, repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 262 | `Note` | C | `ddb_note` | *(container)* | — | — | O | **Y** | — |
| 263 | `note` | E | `ddb_note` | `note` | string, maxLength 65000 | — | R | S | — |
| 264 | `type` | E | `ddb_note` | `note_type` | string, maxLength 50 | **enum** `de_note_type` | O | S | — |
| 265 | `date` | E | `ddb_note` | `note_date` | date | — | R | S | — |

#### Contact (optional, repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 266 | `Contact` | C | `ddb_contact` | *(container)* | — | — | O | **Y** | — |
| 267 | `Person` | E | `ddb_contact` | `person` | string, maxLength 65000 | — | O | **Y** | — |
| 268 | `Address` | E | `ddb_contact` | `address` | string, maxLength 65000 | — | O | **Y** | — |
| 269 | `Email` | E | `ddb_contact` | `email` | string, maxLength 255 | — | O | **Y** | — |
| 270 | `Organisation` | E | `ddb_contact` | `organisation` | string, maxLength 65000 | — | O | **Y** | `Multilingual:true` → `lang_materials` |
| 271 | `Telephone` | E | `ddb_contact` | `telephone` | string, maxLength 50 | — | O | **Y** | — |
| 272 | `Website` | E | `ddb_contact` | `website` | string, maxLength 2048 | — | O | **Y** | `anyURI` → string |

#### Directory (optional, repeatable)
| # | Profile Path | Node | AS Record | AS Field Name | AS Type | Enum / CV | Req | Rpt | Flags |
|---|-------------|------|-----------|---------------|---------|-----------|-----|-----|-------|
| 273 | `Directory` | C | `ddb_directory` | *(container)* | — | — | O | **Y** | — |
| 274 | `directory` | E | `ddb_directory` | `directory` | string, maxLength 255 | — | R | S | — |
| 275 | `level` | E | `ddb_directory` | `level` | string, maxLength 100 | **enum** `de_sensitivity_level` | O | S | — |
| 276 | `description` | E | `ddb_directory` | `description` | string, maxLength 65000 | — | R | S | `Multilingual:true` → `lang_materials` |

---

## 4. Controlled Vocabularies / Enumerations Summary

The profile defines **25 closed enums** across 205 Elements. We map each to an AS `dynamic_enum` (preferred over hard-coded strings for localisation flexibility).

| AS Enum Name | Source Element(s) | Values (from profile) | Count |
|--------------|-------------------|----------------------|-------|
| `de_institute` | `institute` | NL-AsdHI, NL-AsdIISG, NL-AsdMI, NL-AsdNIOD | 4 |
| `de_status` | `status` | under construction, publish | 2 |
| `de_role_in_project` | `roleInProject` | Conceptualization, Data Curation, Formal Analysis, Funding Acquisition, Investigation, Methodology, Project Administration, Resources, Software, Supervision, Validation, Visualization, Writing – Original Draft, Writing – Review & Editing | 14 |
| `de_org_type` | `publishingOrganisation.type` | Academic/Research Institution, Government, Non-Governmental Organisation, Commercial/Private, Other | 5 |
| `de_creator_role` | `Creators.Role` | Conceptualisation, Data Curation, Formal Analysis, Funding Acquisition, Investigation, Methodology, Project Administration, Resources, Software, Supervision, Validation, Visualization, Writing – Original Draft, Writing – Review & Editing | 14 |
| `de_access_level` | `accessLevel` | Open Access, Registered Access, Restricted Access, Embargoed Access, Closed Access | 5 |
| `de_maintenance_status` | `maintenanceStatus` | Regularly maintained, Limited Maintenance, Deprecated, Not maintained | 4 |
| `de_data_subjects` | `Subjects` | Sensitive data about people, Non-sensitive data about people, Sensitive data about animals, Non-sensitive data about animals, Sensitive data about plants, Non-sensitive data about plants, Other | 7 |
| `de_data_modality` | `modality` | Image Data, Text Data, Tabular Data, Audio Data, Video Data, Multimodal Data, Other | 7 |
| `de_yes_no` | `resources`, `confidentialityBin`, `review` | Yes, No | 2 |
| `de_yes_no_not_sure` | `disclaimer` | Yes, No, Not sure | 3 |
| `de_sensitive_attributes` | `sensitiveAttribute` | Gender, Sexuality, Marital Status, Ethnicity, Religion, Political Affiliation, Union Membership, Health/Medical, Genetic/Biometric, Criminal Record, Disability, Socioeconomic Status, Geographic Location, Age, Other | 15 |
| `de_purposes` | `purposes` | Monitoring, Research, Production, Other | 4 |
| `de_dataset_use` | `datasetUse` | Safe for production use, Safe for research use, Safe for educational use, Not safe for any use, Other | 5 |
| `de_safety_level` | `SafetyLevel` | Safe to use with other data, Conditionally safe to use with other data, Unsafe to use with other data | 3 |
| `de_dataset_uses` | `datasetUses` | Training, Testing, Validation, Development, Deployment, Other | 6 |
| `de_sampling_safety` | `safetyLevel` (Sampling) | Safe to sample, Conditionally safe to sample, Unsafe to sample | 3 |
| `de_sampling_methods` | `acceptableSamplingMethods` | Cluster Sampling, Haphazard Sampling, Multi-stage Sampling, Convenience Sampling, Stratified Sampling, Quota Sampling, Simple Random Sampling, Systematic Sampling, Purposive Sampling, Snowball Sampling, Other | 11 |
| `de_annotation_workforce` | `annotationWorkforceType` | Human Annotations (Expert, Employees), Human Annotations (Crowdsourced), Machine Annotations, Human and Machine Annotations, Other | 5 |
| `de_sensitivity_level` | `level` (DDB), `level` (Directory) | non sensitive - open, non sensitive - restricted, sensitive - open, sensitive - restricted | 4 |
| `de_link_type` | `Link.type` | documentation, contract | 2 |
| `de_note_type` | `Note.type` | TODO, done | 2 |

> **Plus 4 more enums** that appear once: `de_link_type`, `de_note_type`, etc. Full list above covers all 25 enum elements.

### SKOS Controlled-Value Links (not enums)

These 6 Elements have `class:skosType` + `autoCompleteURI`. They should **not** be free text; they reference a SKOS concept URI.

| Element | AS Field | SKOS Endpoint (from profile) | Stored as |
|---------|----------|------------------------------|-----------|
| `parent` | `parent_uri` | `/app/stalling/profile/.../entity/envelop` | URI string + label cache |
| `genre` | `genre` | (no explicit URI in profile; generic) | URI string |
| `topic` | `topic` | (no explicit URI) | URI string |
| `languages` | `languages` | (no explicit URI) | URI string |
| `domains` | `domains` | (no explicit URI) | URI string |
| `dataFieldType` | `data_field_type` | (no explicit URI) | URI string |

> **🔒 LOCKED (Pierre, 2026-08-14) — A2:** **Dual field** — store the raw URI **and** a cached `prefLabel` column (like AS `name_authority_id`). Full AS controlled-value source pointing at the SKOS endpoint deferred to WAU-33.

---

## 5. Multilingual Fields → `lang_materials`

7 Elements have `Multilingual: "true"`. Per AS convention, these map to the built-in `lang_materials` array (language + script + content).

| # | Element Path | AS Record | AS Field | Notes |
|---|-------------|-----------|----------|-------|
| 1 | `BasicInformation.title` | `basic_information` | `title` → stored in `lang_materials` | Primary display title |
| 2 | `BasicMetadata.Snapshot.title` | `snapshot` | `title` → `lang_materials` | Snapshot title |
| 3 | `distribution.citation.citationInformation` | `citation` | `citation_information` → `lang_materials` | Citation text |
| 4 | `DDB.description` | `ddb` | `description` → `lang_materials` | DDB description |
| 5 | `DDB.project` | `ddb` | `project` → `lang_materials` | Project name |
| 6 | `DDB.Contact.Organisation` | `ddb_contact` | `organisation` → `lang_materials` | Org name |
| 7 | `DDB.Directory.description` | `ddb_directory` | `description` → `lang_materials` | Directory description |

> **🔒 LOCKED (Pierre, 2026-08-14) — A3:** **Dual-store** — keep a plain scalar string (primary language, for search/index) **plus** the full `lang_materials` array for i18n.

---

## 6. JSONModel Schema Skeleton

```ruby
# schemas/data_envelope.rb
{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "uri" => "/repositories/:repo_id/data_envelopes",
    "properties" => {
      "uri" => {"type" => "string", "required" => false},
      "institute" => {"type" => "string", "dynamic_enum" => "de_institute", "ifmissing" => "error"},
      "data_envelope_id" => {"type" => "string", "maxLength" => 255, "ifmissing" => "error"},
      "parent_uri" => {"type" => "string", "maxLength" => 2048},
      "status" => {"type" => "string", "dynamic_enum" => "de_status", "ifmissing" => "error", "readonly" => "true"},

      # Subrecords
      "basic_information" => {"type" => "JSONModel(:basic_information) object"},
      "basic_metadata" => {"type" => "JSONModel(:basic_metadata) object"},
      "data" => {"type" => "array", "items" => {"type" => "JSONModel(:data_block) object"}},
      "uses" => {"type" => "JSONModel(:uses) object"},
      "human_perspective" => {"type" => "JSONModel(:human_perspective) object"},
      "ddb" => {"type" => "JSONModel(:ddb) object"},

      # Multilingual fallback
      "lang_materials" => {"type" => "array", "items" => {"type" => "JSONModel(:lang_material) object"}},
    },
    "additionalProperties" => false,
  },
}
```

Each subrecord schema follows the same pattern (scalar fields + nested subrecord arrays). The full set of 72 subrecord schemas is omitted here for brevity but is derivable directly from the mapping table above.

---

## 7. Resource Extension (`resource_ext.rb`)

```ruby
{
  "data_envelopes" => {
    "type" => "array",
    "items" => {"type" => "JSONModel(:data_envelope) object"}
  }
}
```

And the mixin `backend/model/mixins/data_envelopes.rb`:

```ruby
module DataEnvelopes
  def self.included(base)
    base.one_to_many :data_envelope
    base.def_nested_record(
      :the_property => :data_envelopes,
      :contains_records_of_type => :data_envelope,
      :corresponding_to_association => :data_envelope
    )
  end
end
```

Then `backend/model/resource.rb`:
```ruby
Resource.include(DataEnvelopes)
```

---

## 8. Decision Points for Lead Engineer — A1/A2/A3 🔒 LOCKED (Pierre, 2026-08-14)

| # | Issue | Options | Recommendation |
|---|-------|---------|----------------|
| A1 | **Subrecord storage: inline JSON vs. independent tables** | (a) All 72 subrecords stored as JSON blobs in `data_envelope.subrecords_json` (simple, no joins). (b) Each repeatable subrecord gets its own table with FK to `data_envelope` (queryable, more complex). | **🔒 LOCKED: Option (a)** — inline JSON blob. Revisit only if search-by-subrecord required (WAU-33+). |
| A2 | **SKOS fields: URI-only vs. resolved label cache** | (a) Store raw URI string only. (b) Store URI + resolved prefLabel in a dual field. (c) Implement full AS controlled-value source pointing to SKOS endpoint. | **🔒 LOCKED: Option (b)** — dual URI + prefLabel cache. Full SKOS source deferred to WAU-33. |
| A3 | **Multilingual fields: scalar + lang_materials vs. lang_materials only** | (a) Keep scalar field for simple display + `lang_materials` for i18n. (b) Drop scalar; rely solely on `lang_materials`. | **🔒 LOCKED: Option (a)** — dual-store (scalar for search + `lang_materials` for i18n). |
| A4 | **Enums: AS `dynamic_enum` vs. hard-coded validation** | (a) `dynamic_enum` — editable by admins, translatable. (b) Hard-code in schema `enum` array — simpler but rigid. | **Option (a)** — AS `dynamic_enum` for all 21+ enums. |
| A5 | **Decimal fields: string vs. number** | (a) Store as string (preserves exact input). (b) Store as AS "real" number type. | **Option (a)** — string avoids float precision issues; can add `pattern` validation if needed. |
| A6 | **DDB block optional at root but required fields inside** | If `DDB` is absent, its required children are moot. Converter must handle this in WAU-32. | Documented; no decision needed. |
| A7 | **Duplicate component names** (`Dates`, `Creators`, `feedbackElaboration`) | (a) Unique subrecord names per parent (used in this proposal). (b) Reuse same subrecord type everywhere (ambiguous). | **Option (a)** — this proposal already uses unique names. |
| A8 | **DataEnvelope as standalone record type vs. subtype of Resource** | (a) Standalone with own URI space (`/data_envelopes`). (b) Subtype of Resource (inherits AS resource fields). | **Option (a)** — matches prior decision; standalone record with optional nesting on Resource. |

---

## 9. Verification Checklist

| Requirement | Status |
|-------------|--------|
| All 277 nodes mapped | ✅ Yes (table rows 1–275 + 2 root metadata = 277) |
| 10 top-level children accounted for | ✅ Yes (institute, ID, parent, status, BasicInformation, BasicMetadata, Data, Uses, HumanPerspective, DDB) |
| Component → subrecord | ✅ All 72 Components map to distinct AS subrecord types |
| Element → field with type | ✅ All 205 Elements mapped to AS field + type |
| Enum → `dynamic_enum` | ✅ 25 enum elements mapped to 21 AS enums |
| SKOS → controlled-value link | ✅ 6 SKOS elements flagged with `class:skosType` |
| `class:status` + `readonly` → system-managed | ✅ `status` field marked `readonly` in schema |
| `Multilingual:true` → `lang_materials` | ✅ 7 multilingual fields identified |
| CardinalityMin/Max → required/optional/repeatable | ✅ All fields tagged R/O and S/Y |
| Plugin skeleton follows hello_world | ✅ Yes |

---

*End of WAU-31 proposal. Ready for Lead Engineer review before WAU-32 implementation.*
