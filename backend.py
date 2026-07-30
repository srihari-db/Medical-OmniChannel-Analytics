"""Data access layer for the Medical Engagement Copilot.

Reads the governed Gold tables in <catalog>.<schema> via a SQL warehouse and
generates AI briefings with ai_query() on a Databricks LLM endpoint. All auth
uses the SDK Config() (service-principal on Databricks Apps); no hardcoded
tokens or resource IDs.
"""
import os
import functools
from databricks.sdk.core import Config
from databricks import sql

CATALOG = os.getenv("MOE_CATALOG", "_sa701")
SCHEMA = os.getenv("MOE_SCHEMA", "moe")
LLM_ENDPOINT = os.getenv("MOE_LLM_ENDPOINT", "databricks-meta-llama-3-3-70b-instruct")
FQ = f"`{CATALOG}`.`{SCHEMA}`"

_cfg = Config()


def _connect():
    return sql.connect(
        server_hostname=_cfg.host,
        http_path=f"/sql/1.0/warehouses/{os.environ['DATABRICKS_WAREHOUSE_ID']}",
        credentials_provider=lambda: _cfg.authenticate,
    )


def _rows(query, params=None):
    """Run a query and return a list of dicts."""
    with _connect() as conn:
        with conn.cursor() as cur:
            cur.execute(query, params or {})
            cols = [c[0] for c in cur.description]
            return [dict(zip(cols, r)) for r in cur.fetchall()]


def _one(query, params=None):
    rs = _rows(query, params)
    return rs[0] if rs else None


# ---------------------------------------------------------------- HCP list ---
@functools.lru_cache(maxsize=1)
def list_hcps():
    """Return HCPs ordered so high-priority ones surface first for the demo."""
    return _rows(f"""
        SELECT p.hcp_id, h.hcp_name, h.specialty, h.territory, h.hcp_tier,
               p.msl_priority_score, p.priority_tier
        FROM {FQ}.gold_hcp_priority p
        JOIN {FQ}.gold_hcp_360 h USING (hcp_id)
        ORDER BY p.msl_priority_score DESC, h.hcp_name
    """)


# ------------------------------------------------------------ HCP profile ----
def get_profile(hcp_id):
    return _one(f"""
        SELECT * FROM {FQ}.gold_hcp_360 WHERE hcp_id = %(hcp_id)s
    """, {"hcp_id": hcp_id})


def get_priority(hcp_id):
    return _one(f"""
        SELECT * FROM {FQ}.gold_hcp_priority WHERE hcp_id = %(hcp_id)s
    """, {"hcp_id": hcp_id})


def get_recent_interactions(hcp_id, limit=5):
    return _rows(f"""
        SELECT interaction_date, channel, msl_name, topic_category, scientific_topic,
               information_need, sentiment, interest_level, follow_up_requested,
               competitor_mentioned, evidence_type_requested
        FROM {FQ}.silver_msl_extracted
        WHERE hcp_id = %(hcp_id)s
        ORDER BY interaction_date DESC
        LIMIT {int(limit)}
    """, {"hcp_id": hcp_id})


def get_topic_interests(hcp_id):
    return _rows(f"""
        SELECT topic_category, mentions, topic_interest_score,
               mentions_current_30d, mentions_prior_30d, last_mention_date
        FROM {FQ}.gold_medical_topic_interest
        WHERE hcp_id = %(hcp_id)s
        ORDER BY topic_interest_score DESC, mentions DESC
    """, {"hcp_id": hcp_id})


def get_inquiries(hcp_id, limit=5):
    return _rows(f"""
        SELECT inquiry_date, inquiry_topic, evidence_type_requested, indication,
               product, response_status, response_time_days, overdue
        FROM {FQ}.gold_medical_information_requests
        WHERE hcp_id = %(hcp_id)s
        ORDER BY inquiry_date DESC
        LIMIT {int(limit)}
    """, {"hcp_id": hcp_id})


def get_congress(hcp_id):
    return _one(f"""
        SELECT sessions_attended, booth_visits, distinct_events, session_topics,
               last_congress_date
        FROM {FQ}.gold_congress_engagement
        WHERE hcp_id = %(hcp_id)s
    """, {"hcp_id": hcp_id})


def get_publications(hcp_id, limit=8):
    return _rows(f"""
        SELECT record_type, title, journal_or_registry, year, therapeutic_area, trial_id
        FROM {FQ}.publications_trials
        WHERE hcp_id = %(hcp_id)s
        ORDER BY year DESC
        LIMIT {int(limit)}
    """, {"hcp_id": hcp_id})


def get_content_shared(hcp_id):
    return _rows(f"""
        SELECT shared_date, content_title, content_type, topic_category,
               shared_by_msl, share_channel
        FROM {FQ}.gold_content_shared
        WHERE hcp_id = %(hcp_id)s
        ORDER BY shared_date DESC
    """, {"hcp_id": hcp_id})


def get_next_best(hcp_id):
    return _one(f"""
        SELECT trigger, suggested_engagement, topic, suggested_channel_topic,
               recommended_date, overdue, review_status
        FROM {FQ}.gold_next_best_engagement
        WHERE hcp_id = %(hcp_id)s
    """, {"hcp_id": hcp_id})


# --------------------------------------------------- approved content rec ----
def recommend_content(hcp_id):
    """Recommend an approved asset matched to the HCP's top interest that has
    NOT already been shared with them (governed, non-duplicative)."""
    return _one(f"""
        WITH top_topic AS (
          SELECT topic_category
          FROM {FQ}.gold_medical_topic_interest
          WHERE hcp_id = %(hcp_id)s
          ORDER BY topic_interest_score DESC, mentions DESC
          LIMIT 1
        ),
        already AS (
          SELECT DISTINCT content_id FROM {FQ}.gold_content_shared WHERE hcp_id = %(hcp_id)s
        )
        SELECT c.content_id, c.content_title, c.content_type, c.topic_category,
               c.indication, c.product, c.approval_status, c.med_review_id, c.approval_date
        FROM {FQ}.gold_approved_content c
        JOIN top_topic t ON c.topic_category = t.topic_category
        WHERE c.content_id NOT IN (SELECT content_id FROM already)
          AND c.approval_status = 'Approved'
        ORDER BY c.approval_date DESC
        LIMIT 1
    """, {"hcp_id": hcp_id})


# --------------------------------------------------------- AI briefing -------
def _sql_str(s):
    return "'" + str(s).replace("'", "''") + "'"


def generate_briefing(context_text):
    """Generate the narrative pre-engagement briefing via ai_query()."""
    prompt = (
        "You are a Medical Science Liaison (MSL) assistant for a Medical Affairs team in oncology. "
        "Using ONLY the structured HCP context below, write a concise 3-4 sentence pre-engagement "
        "briefing for the MSL. Focus on the HCP's recent scientific interests, unmet information "
        "needs, congress activity, and any outstanding follow-up. Be factual, non-promotional, and "
        "reference approved scientific evidence only. Do NOT invent data not present in the context. "
        "End with a suggested discussion point. Context:\n" + context_text
    )
    q = f"SELECT ai_query({_sql_str(LLM_ENDPOINT)}, {_sql_str(prompt)}) AS briefing"
    row = _one(q)
    return (row or {}).get("briefing", "").strip()
