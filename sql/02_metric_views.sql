-- Unity Catalog Metric Views for the Medical Omnichannel Intelligence demo
-- Schema: _sa701.moe
-- Governed business metrics reused across the AI/BI dashboard and the Genie space.

-- =============================================================================
-- metric_hcp_engagement
-- Governed Medical Affairs HCP engagement metrics for reuse across dashboards and Genie
-- =============================================================================
CREATE OR REPLACE VIEW _sa701.moe.metric_hcp_engagement (
  Territory,
  Specialty,
  `HCP Tier`,
  `Practice Setting`,
  `Therapeutic Area`,
  `Top Scientific Topic`,
  `Preferred Channel`,
  `Total HCPs`,
  `HCPs Engaged 90d`,
  `HCP Reach Pct`,
  `Under Engaged Priority HCPs`,
  `Avg Engagement Score`,
  `Avg Educational Need Score`,
  `Avg Influence Score`,
  `Total MSL Interactions`,
  `Avg Email Open Rate`,
  `Open Follow Ups`)
COMMENT 'Governed Medical Affairs HCP engagement metrics for reuse across dashboards and Genie'
WITH METRICS
LANGUAGE YAML
AS $$
version: 0.1
source: _sa701.moe.gold_hcp_360
dimensions:
  - name: Territory
    expr: territory
  - name: Specialty
    expr: specialty
  - name: HCP Tier
    expr: hcp_tier
  - name: Practice Setting
    expr: practice_setting
  - name: Therapeutic Area
    expr: primary_therapeutic_area
  - name: Top Scientific Topic
    expr: top_scientific_topic
  - name: Preferred Channel
    expr: preferred_engagement_channel
measures:
  - name: Total HCPs
    expr: COUNT(DISTINCT hcp_id)
  - name: HCPs Engaged 90d
    expr: COUNT(DISTINCT CASE WHEN days_since_last_msl <= 90 THEN hcp_id END)
  - name: HCP Reach Pct
    expr: COUNT(DISTINCT CASE WHEN days_since_last_msl <= 90 THEN hcp_id END) * 100.0 / NULLIF(COUNT(DISTINCT hcp_id),0)
  - name: Under Engaged Priority HCPs
    expr: COUNT(DISTINCT CASE WHEN under_engaged_priority THEN hcp_id END)
  - name: Avg Engagement Score
    expr: AVG(engagement_score)
  - name: Avg Educational Need Score
    expr: AVG(educational_need_score)
  - name: Avg Influence Score
    expr: AVG(influence_score)
  - name: Total MSL Interactions
    expr: SUM(msl_interactions)
  - name: Avg Email Open Rate
    expr: AVG(email_open_rate)
  - name: Open Follow Ups
    expr: SUM(follow_ups_requested)
$$;

-- =============================================================================
-- metric_medical_inquiries
-- Governed Medical Information / inquiry SLA metrics
-- =============================================================================
CREATE OR REPLACE VIEW _sa701.moe.metric_medical_inquiries (
  `Inquiry Topic`,
  `Evidence Type`,
  Indication,
  Product,
  `Response Status`,
  `Inquiry Month`,
  `Total Inquiries`,
  `Open Inquiries`,
  `Overdue Inquiries`,
  `Avg Response Days`,
  `SLA Met Pct`)
COMMENT 'Governed Medical Information / inquiry SLA metrics'
WITH METRICS
LANGUAGE YAML
AS $$
version: 0.1
source: _sa701.moe.gold_medical_information_requests
dimensions:
  - name: Inquiry Topic
    expr: inquiry_topic
  - name: Evidence Type
    expr: evidence_type_requested
  - name: Indication
    expr: indication
  - name: Product
    expr: product
  - name: Response Status
    expr: response_status
  - name: Inquiry Month
    expr: DATE_TRUNC('MONTH', inquiry_date)
measures:
  - name: Total Inquiries
    expr: COUNT(*)
  - name: Open Inquiries
    expr: COUNT(CASE WHEN response_status = 'Open' THEN 1 END)
  - name: Overdue Inquiries
    expr: COUNT(CASE WHEN overdue THEN 1 END)
  - name: Avg Response Days
    expr: AVG(response_time_days)
  - name: SLA Met Pct
    expr: COUNT(CASE WHEN sla_met THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN response_status='Closed' THEN 1 END),0)
$$;
