# Medical OmniChannel Analytics

End-to-end **Medical Affairs Omnichannel Intelligence** demo on Databricks. It brings
together a governed Unity Catalog data layer, governed business metrics, a natural-language
**Genie** space, an **AI/BI dashboard**, and a **Databricks App** ("Medical Engagement
Copilot") that generates pre-engagement briefings for Medical Science Liaisons (MSLs).

All data is **synthetic** and the context is **Medical Affairs (non-promotional)**. Every
AI output is a recommendation for **human (MSL) review**, not an automated action.

> Built on Databricks in the `e2-demo-field-eng` workspace. Data assets live in the
> Unity Catalog schema **`_sa701.moe`**.

## Repository layout

```
.
├── app/                         # Databricks App — "Medical Engagement Copilot"
│   ├── app.py                   #   Streamlit/Dash UI
│   ├── backend.py               #   SQL + ai_query() logic over _sa701.moe
│   ├── app.yaml                 #   App config (resources, env)
│   ├── requirements.txt
│   └── README.md                #   App-specific docs
├── sql/                         # Unity Catalog data layer (reproducible DDL)
│   ├── 00_schema_and_volume.sql #   schema + source_documents volume
│   ├── 01_tables.sql            #   all source/silver/gold table schemas
│   └── 02_metric_views.sql      #   governed metric views
├── data/
│   ├── genie/                   # Genie space definition (tables + sample questions)
│   ├── dashboard/               # AI/BI dashboard (.lvdash.json)
│   └── source_documents/        # sample source doc (MSL field notes PDF)
└── README.md
```

## Assets in this demo

| Asset | Type | Where |
|-------|------|-------|
| `_sa701.moe` schema | Unity Catalog schema | `sql/00_schema_and_volume.sql` |
| 19 tables (source, silver, gold, content) | Delta tables | `sql/01_tables.sql` |
| `metric_hcp_engagement`, `metric_medical_inquiries` | Metric views | `sql/02_metric_views.sql` |
| `source_documents` | UC Volume (+ `msl_field_notes.pdf`) | `data/source_documents/` |
| Medical Omnichannel Intelligence | Genie space | `data/genie/` |
| Medical Omnichannel Intelligence | AI/BI dashboard | `data/dashboard/` |
| Medical Engagement Copilot | Databricks App | `app/` |

## Data layer (`_sa701.moe`)

- **Source / Bronze** — `hcp_master`, `msl_interactions` (free-text notes),
  `medical_inquiries`, `congress_events`, `digital_engagement`, `publications_trials`,
  `patient_claims_summary`.
- **Silver** — `silver_msl_extracted`: structured fields (scientific topic, information
  need, sentiment, follow-up, competitor mention…) extracted from MSL raw notes with
  `ai_query()`.
- **Gold** — `gold_hcp_360`, `gold_hcp_priority`, `gold_medical_topic_interest`,
  `gold_msl_interaction_summary`, `gold_medical_information_requests`,
  `gold_congress_engagement`, `gold_territory_opportunity`, `gold_next_best_engagement`,
  `gold_hcp_channel_engagement`.
- **Content** — `gold_approved_content` (medically-approved assets w/ review IDs),
  `gold_content_shared`.
- **Metric views** — governed KPIs (`metric_hcp_engagement`, `metric_medical_inquiries`)
  reused by both the dashboard and Genie.

## Recreating the assets

The `sql/` files reproduce the **physical schema** (empty tables + metric views). They do
not include the synthetic data generation / transformation logic — populate the tables
with your own generator, then the gold tables via the documented aggregation rules.

```bash
# 1. Data layer (run in order against a SQL warehouse)
databricks sql ... < sql/00_schema_and_volume.sql
databricks sql ... < sql/01_tables.sql
databricks sql ... < sql/02_metric_views.sql

# 2. Genie space  — import data/genie/medical_omnichannel_intelligence.genie.json
# 3. Dashboard    — import data/dashboard/medical_omnichannel_intelligence.lvdash.json
# 4. App          — deploy app/ as a Databricks App
```

## Notes
- `warehouse_id` values inside the Genie / dashboard JSON are environment-specific — repoint
  them to your own SQL warehouse on import.
- The app reads governed Gold tables and calls a Databricks LLM endpoint via `ai_query()`
  (`MOE_LLM_ENDPOINT`, default `databricks-meta-llama-3-3-70b-instruct`).
