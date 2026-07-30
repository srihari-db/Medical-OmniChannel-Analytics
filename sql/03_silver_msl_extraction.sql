-- =============================================================================
-- Silver: extract structured fields from MSL free-text notes with ai_query()
-- Source : _sa701.moe.msl_interactions (raw_notes)
-- Target : _sa701.moe.silver_msl_extracted
-- Model  : databricks-meta-llama-3-3-70b-instruct
--
-- This is the logic that turns the single `raw_notes` column into the 12+
-- structured columns (therapeutic_area, scientific_topic, information_need,
-- product_or_indication, sentiment, interest_level, follow_up_requested,
-- competitor_mentioned, preferred_channel, evidence_type_requested, ...).
--
-- Run STEP 1, then STEP 2. Step 2 fills nulls from any rows whose JSON failed
-- to parse AND derives the `topic_category` bucket used by the dashboard/Genie.
-- Recovered verbatim from e2-demo query history (2026-07-27).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- STEP 1 — LLM JSON extraction from raw_notes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE _sa701.moe.silver_msl_extracted AS
WITH raw AS (
  SELECT interaction_id, hcp_id, msl_name, interaction_date, channel, duration_minutes, raw_notes,
    regexp_replace(
      ai_query(
        'databricks-meta-llama-3-3-70b-instruct',
        concat(
          'You are a Medical Affairs analyst. Extract structured fields from this MSL interaction note as JSON with EXACTLY these keys: ',
          'therapeutic_area, scientific_topic, information_need, product_or_indication, sentiment (one of Positive/Neutral/Negative), ',
          'interest_level (one of High/Medium/Low), follow_up_requested (true or false), competitor_mentioned (competitor name or None), ',
          'preferred_channel (one of In-person/Virtual/Phone/Email/Congress/None), evidence_type_requested. ',
          'Return ONLY valid minified JSON, no markdown, no prose. Note: ',
          raw_notes)
      ),
      '```(json)?', '') AS extracted_raw
  FROM _sa701.moe.msl_interactions
),
parsed AS (
  SELECT *, from_json(trim(extracted_raw),
    'therapeutic_area STRING, scientific_topic STRING, information_need STRING, product_or_indication STRING, sentiment STRING, interest_level STRING, follow_up_requested BOOLEAN, competitor_mentioned STRING, preferred_channel STRING, evidence_type_requested STRING') AS j
  FROM raw
)
SELECT interaction_id, hcp_id, msl_name, interaction_date, channel, duration_minutes,
  j.therapeutic_area, j.scientific_topic, j.information_need, j.product_or_indication,
  j.sentiment, j.interest_level, j.follow_up_requested, j.competitor_mentioned,
  j.preferred_channel, j.evidence_type_requested,
  CASE WHEN j.follow_up_requested THEN date_add(interaction_date, 14) ELSE NULL END AS recommended_follow_up_date,
  raw_notes
FROM parsed;

-- -----------------------------------------------------------------------------
-- STEP 2 — Backfill nulls (rows where JSON parse failed) with a stricter
--          single-field extraction, and derive topic_category buckets.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE _sa701.moe.silver_msl_extracted AS
WITH cur AS (SELECT * FROM _sa701.moe.silver_msl_extracted),
fixed AS (
  SELECT
    interaction_id, hcp_id, msl_name, interaction_date, channel, duration_minutes,
    coalesce(therapeutic_area, 'Oncology') AS therapeutic_area,
    coalesce(scientific_topic,
      ai_query('databricks-meta-llama-3-3-70b-instruct',
        concat('In 3-6 words, state the single main scientific topic of this MSL note. Return only the phrase. Note: ', raw_notes))
    ) AS scientific_topic,
    coalesce(information_need, 'Scientific information request') AS information_need,
    coalesce(product_or_indication, 'Portfolio') AS product_or_indication,
    coalesce(sentiment, 'Neutral') AS sentiment,
    coalesce(interest_level, 'Medium') AS interest_level,
    coalesce(follow_up_requested, false) AS follow_up_requested,
    coalesce(competitor_mentioned, 'None') AS competitor_mentioned,
    coalesce(nullif(preferred_channel,'None'), channel) AS preferred_channel,
    coalesce(evidence_type_requested, 'Efficacy') AS evidence_type_requested,
    recommended_follow_up_date, raw_notes
  FROM cur
)
SELECT *,
  CASE
    WHEN lower(scientific_topic) RLIKE 'ild|pneumonitis|interstitial|lung|safety|adverse|toxicity' THEN 'Safety / ILD Management'
    WHEN lower(scientific_topic) RLIKE 'real-world|rwe|real world' THEN 'Real-World Evidence'
    WHEN lower(scientific_topic) RLIKE 'long-term|duration of response|outcome' THEN 'Long-term Efficacy & Outcomes'
    WHEN lower(scientific_topic) RLIKE 'biomarker|trop2|her2|testing|diagnostic|selection|amplif' THEN 'Biomarker & Patient Selection'
    WHEN lower(scientific_topic) RLIKE 'cns|brain|metasta' THEN 'CNS / Brain Metastases'
    WHEN lower(scientific_topic) RLIKE 'dosing|dose|administration|nausea|management' THEN 'Dosing & Administration'
    WHEN lower(scientific_topic) RLIKE 'sequenc|resistance|combination|immunotherap' THEN 'Sequencing & Combinations'
    WHEN lower(scientific_topic) RLIKE 'comparative|head-to-head|versus|compar' THEN 'Comparative Evidence'
    WHEN lower(scientific_topic) RLIKE 'efficacy' THEN 'Long-term Efficacy & Outcomes'
    ELSE 'General Scientific Exchange'
  END AS topic_category
FROM fixed;
