-- Table schemas (DDL) for the Medical Omnichannel Intelligence demo
-- Catalog.Schema: _sa701.moe
--
-- Layers:
--   Source / Bronze : hcp_master, msl_interactions, medical_inquiries, congress_events,
--                     digital_engagement, publications_trials, patient_claims_summary
--   Silver          : silver_msl_extracted (LLM-extracted structure from MSL raw notes)
--   Gold            : gold_* aggregate / analytics tables
--   Content         : gold_approved_content, gold_content_shared
--
-- All data is SYNTHETIC for demonstration. Reproduces the physical schema only;
-- populate with your own data-generation / transformation logic.

-- =========================================================================
-- SOURCE / BRONZE
-- =========================================================================

CREATE TABLE IF NOT EXISTS _sa701.moe.hcp_master (
  hcp_id STRING,
  hcp_name STRING,
  specialty STRING,
  institution STRING,
  city STRING,
  state STRING,
  territory STRING,
  practice_setting STRING,
  hcp_tier STRING,
  publication_count INT,
  trial_participation INT,
  influence_score INT,
  npi STRING,
  primary_therapeutic_area STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.msl_interactions (
  interaction_id STRING,
  hcp_id STRING,
  msl_name STRING,
  interaction_date DATE,
  channel STRING,
  duration_minutes INT,
  raw_notes STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.medical_inquiries (
  inquiry_id STRING,
  hcp_id STRING,
  inquiry_date DATE,
  inquiry_topic STRING,
  evidence_type_requested STRING,
  indication STRING,
  response_status STRING,
  response_time_days INT,
  sla_met BOOLEAN,
  sla_target_days INT,
  product STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.congress_events (
  event_attendance_id STRING,
  hcp_id STRING,
  event_name STRING,
  event_date DATE,
  session_topic STRING,
  therapeutic_area STRING,
  attendance_status STRING,
  visited_medical_booth BOOLEAN)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.digital_engagement (
  engagement_id STRING,
  hcp_id STRING,
  activity_date DATE,
  emails_sent INT,
  emails_opened INT,
  content_title STRING,
  content_type STRING,
  webpage_clicks INT,
  attended_webinar BOOLEAN,
  content_minutes_viewed INT)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.publications_trials (
  record_id STRING,
  hcp_id STRING,
  record_type STRING,
  title STRING,
  journal_or_registry STRING,
  year INT,
  therapeutic_area STRING,
  trial_id STRING,
  citation_count INT)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.patient_claims_summary (
  claim_summary_id STRING,
  city STRING,
  state STRING,
  territory STRING,
  diagnosis STRING,
  primary_therapy STRING,
  diagnosed_patient_count INT,
  treated_patient_count INT,
  treatment_penetration_rate DECIMAL(15,2))
USING delta;

-- =========================================================================
-- SILVER  (LLM-extracted structure from MSL free-text notes via ai_query)
-- =========================================================================

CREATE TABLE IF NOT EXISTS _sa701.moe.silver_msl_extracted (
  interaction_id STRING,
  hcp_id STRING,
  msl_name STRING,
  interaction_date DATE,
  channel STRING,
  duration_minutes INT,
  therapeutic_area STRING,
  scientific_topic STRING,
  information_need STRING,
  product_or_indication STRING,
  sentiment STRING,
  interest_level STRING,
  follow_up_requested BOOLEAN,
  competitor_mentioned STRING,
  preferred_channel STRING,
  evidence_type_requested STRING,
  recommended_follow_up_date DATE,
  raw_notes STRING,
  topic_category STRING)
USING delta;

-- =========================================================================
-- GOLD
-- =========================================================================

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_hcp_360 (
  hcp_id STRING,
  hcp_name STRING,
  specialty STRING,
  institution STRING,
  city STRING,
  state STRING,
  territory STRING,
  practice_setting STRING,
  hcp_tier STRING,
  primary_therapeutic_area STRING,
  publication_count INT,
  trial_participation INT,
  influence_score INT,
  npi STRING,
  msl_interactions BIGINT,
  avg_msl_duration_min DOUBLE,
  email_open_rate DOUBLE,
  webinars_attended BIGINT,
  congress_sessions_attended BIGINT,
  medical_inquiries BIGINT,
  channels_used INT,
  last_any_engagement DATE,
  interactions_30d BIGINT,
  interactions_90d BIGINT,
  interactions_180d BIGINT,
  days_since_last_msl INT,
  follow_ups_requested BIGINT,
  top_scientific_topic STRING,
  top_topic_interest_score DOUBLE,
  emerging_topics ARRAY<STRING>,
  recent_question STRING,
  recent_evidence_request STRING,
  recent_competitor_interest STRING,
  publications_tracked BIGINT,
  trials_tracked BIGINT,
  educational_need_score DOUBLE,
  digital_engagement_score DOUBLE,
  engagement_score DOUBLE,
  under_engaged_priority BOOLEAN,
  avg_engagement_duration DOUBLE,
  preferred_engagement_channel STRING,
  recommended_follow_up_window STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_hcp_priority (
  hcp_id STRING,
  hcp_name STRING,
  specialty STRING,
  territory STRING,
  hcp_tier STRING,
  primary_therapeutic_area STRING,
  influence_score INT,
  engagement_score DOUBLE,
  educational_need_score DOUBLE,
  digital_engagement_score DOUBLE,
  under_engaged_priority BOOLEAN,
  days_since_last_msl INT,
  follow_ups_requested BIGINT,
  top_scientific_topic STRING,
  top_topic_interest_score DOUBLE,
  recent_competitor_interest STRING,
  msl_priority_score DOUBLE,
  engagement_segment STRING,
  priority_tier STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_medical_topic_interest (
  hcp_id STRING,
  topic_category STRING,
  mentions BIGINT,
  mentions_current_30d BIGINT,
  mentions_prior_30d BIGINT,
  avg_interest_weight DOUBLE,
  last_mention_date DATE,
  topic_interest_score DOUBLE)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_msl_interaction_summary (
  hcp_id STRING,
  total_interactions BIGINT,
  interactions_30d BIGINT,
  interactions_90d BIGINT,
  interactions_180d BIGINT,
  avg_duration_min DOUBLE,
  last_interaction_date DATE,
  days_since_last_interaction INT,
  follow_ups_requested BIGINT,
  distinct_topics BIGINT,
  sample_sentiment STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_medical_information_requests (
  inquiry_id STRING,
  hcp_id STRING,
  inquiry_date DATE,
  inquiry_topic STRING,
  evidence_type_requested STRING,
  indication STRING,
  product STRING,
  response_status STRING,
  response_time_days INT,
  sla_target_days INT,
  sla_met BOOLEAN,
  overdue BOOLEAN)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_congress_engagement (
  hcp_id STRING,
  hcp_name STRING,
  territory STRING,
  specialty STRING,
  sessions_registered BIGINT,
  sessions_attended BIGINT,
  booth_visits BIGINT,
  distinct_events BIGINT,
  session_topics ARRAY<STRING>,
  last_congress_date DATE)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_territory_opportunity (
  territory STRING,
  total_hcps BIGINT,
  priority_hcps BIGINT,
  engaged_90d BIGINT,
  under_engaged_priority_hcps BIGINT,
  reach_rate DOUBLE,
  avg_engagement_score DOUBLE,
  avg_educational_need DOUBLE,
  diagnosed_patients BIGINT,
  treated_patients BIGINT,
  avg_treatment_penetration DECIMAL(16,2),
  territory_opportunity_score DOUBLE)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_next_best_engagement (
  hcp_id STRING,
  hcp_name STRING,
  specialty STRING,
  territory STRING,
  priority_tier STRING,
  msl_priority_score DOUBLE,
  engagement_segment STRING,
  trigger STRING,
  topic STRING,
  suggested_engagement STRING,
  suggested_channel_topic STRING,
  recommended_date DATE,
  overdue BOOLEAN,
  review_status STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_hcp_channel_engagement (
  hcp_id STRING,
  hcp_name STRING,
  territory STRING,
  specialty STRING,
  msl_interactions BIGINT,
  avg_msl_duration_min DOUBLE,
  emails_sent BIGINT,
  emails_opened BIGINT,
  email_open_rate DOUBLE,
  webpage_clicks BIGINT,
  webinars_attended BIGINT,
  congress_sessions_attended BIGINT,
  medical_inquiries BIGINT,
  channels_used INT,
  last_msl_date DATE,
  last_digital_date DATE,
  last_congress_date DATE,
  last_inquiry_date DATE,
  last_any_engagement DATE)
USING delta;

-- =========================================================================
-- CONTENT  (medically-approved assets + share log)
-- =========================================================================

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_approved_content (
  content_id STRING,
  content_title STRING,
  content_type STRING,
  topic_category STRING,
  indication STRING,
  product STRING,
  approval_date STRING,
  approval_status STRING,
  med_review_id STRING)
USING delta;

CREATE TABLE IF NOT EXISTS _sa701.moe.gold_content_shared (
  share_id STRING,
  hcp_id STRING,
  content_id STRING,
  content_title STRING,
  content_type STRING,
  topic_category STRING,
  shared_date DATE,
  shared_by_msl STRING,
  share_channel STRING)
USING delta;
