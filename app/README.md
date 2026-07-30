# Medical Engagement Copilot

Art-of-the-possible Databricks App for the **Medical Omnichannel Intelligence** demo.

Select an HCP and get a pre-engagement briefing that brings together **analytics, AI,
governed content, and action**:

- **HCP 360 summary** — profile & institution, recent MSL interactions, top scientific
  interests, recent medical inquiries, congress participation, publications & trials,
  approved content previously shared, outstanding follow-ups.
- **AI-generated briefing** — a 3–4 sentence narrative produced with `ai_query()` on a
  Databricks LLM endpoint, grounded only in the HCP's structured context.
- **Suggested engagement plan** — objective, topic, supporting **approved** asset,
  preferred channel, timing, and required MSL review.
- **Governed content recommendation** — matched to the HCP's top interest, only surfaces
  medically-approved assets (with review ID) not already shared.

All outputs are recommendations for **human (MSL) review** — not automated actions, and
kept in a Medical Affairs (non-promotional) context. Data is synthetic.

## Data
Reads governed Gold tables in `_sa701.moe`:
`gold_hcp_360`, `gold_hcp_priority`, `silver_msl_extracted`, `gold_medical_topic_interest`,
`gold_medical_information_requests`, `gold_congress_engagement`, `publications_trials`,
`gold_approved_content`, `gold_content_shared`, `gold_next_best_engagement`.

## Resources
- **sql_warehouse** — SQL warehouse (injected as `DATABRICKS_WAREHOUSE_ID`)
- LLM endpoint via `MOE_LLM_ENDPOINT` (default `databricks-meta-llama-3-3-70b-instruct`)
