"""Medical Engagement Copilot — pre-engagement briefing for Medical Affairs / MSLs.

Art-of-the-possible workflow: select an HCP -> unified 360 summary -> AI-generated
briefing -> suggested engagement plan with an approved-content recommendation.
All recommendations are for human (MSL) review. Data is synthetic (demo).
"""
import datetime
import streamlit as st
import backend as be

st.set_page_config(page_title="Medical Engagement Copilot", page_icon="🧬", layout="wide")

# ---------------------------------------------------------------- styling ---
st.markdown("""
<style>
  .block-container {padding-top: 2rem; max-width: 1300px;}
  .mec-card {background:#F7F9FC; border:1px solid #E3E8EF; border-radius:12px; padding:16px 18px; margin-bottom:12px;}
  .mec-brief {background:#EEF4FF; border-left:5px solid #2D5BFF; border-radius:8px; padding:16px 20px; font-size:1.02rem; line-height:1.5;}
  .mec-plan {background:#F3FBF4; border-left:5px solid #1F9D55; border-radius:8px; padding:16px 20px;}
  .mec-gov {background:#FFF8ED; border-left:5px solid #D9822B; border-radius:8px; padding:12px 16px; font-size:0.9rem;}
  .mec-pill {display:inline-block; padding:2px 10px; border-radius:12px; font-size:0.78rem; font-weight:600; margin-right:6px;}
  .pill-high {background:#FDE4E1; color:#B4231A;}
  .pill-med {background:#FEF3CD; color:#8A6100;}
  .pill-low {background:#E1ECFB; color:#1F5199;}
  h1 {font-size:1.9rem;}
  .mec-label {color:#5A6472; font-size:0.8rem; text-transform:uppercase; letter-spacing:0.04em;}
</style>
""", unsafe_allow_html=True)

st.title("🧬 Medical Engagement Copilot")
st.caption("Pre-engagement briefing for Medical Affairs · unified HCP 360 + AI + governed content · "
           "**all recommendations require MSL review** · synthetic demo data")


def pill(tier):
    t = (tier or "").lower()
    cls = "pill-high" if "high" in t else "pill-med" if "medium" in t else "pill-low"
    return f'<span class="mec-pill {cls}">{tier}</span>'


def fmt_date(d):
    if d is None:
        return "—"
    if isinstance(d, (datetime.date, datetime.datetime)):
        return d.strftime("%Y-%m-%d")
    return str(d)


# --------------------------------------------------------------- sidebar ----
try:
    hcps = be.list_hcps()
except Exception as e:
    st.error(f"Could not load HCP list. Check the app's SQL warehouse resource and permissions.\n\n{e}")
    st.stop()

hcp_by_label = {}
for h in hcps:
    label = f"{h['hcp_name']} — {h['specialty']} ({h['territory']}) · priority {h['msl_priority_score']:.0f}"
    hcp_by_label[label] = h

with st.sidebar:
    st.header("Select HCP")
    st.caption(f"{len(hcps)} HCPs · sorted by MSL priority score")
    choice = st.selectbox("Healthcare Professional", list(hcp_by_label.keys()))
    selected = hcp_by_label[choice]
    hcp_id = selected["hcp_id"]
    st.markdown(f"**{selected['hcp_name']}**")
    st.markdown(pill(selected["priority_tier"]), unsafe_allow_html=True)
    gen = st.button("🧠 Generate AI briefing", type="primary", use_container_width=True)

# --------------------------------------------------------- load HCP data ----
profile = be.get_profile(hcp_id)
priority = be.get_priority(hcp_id)
interactions = be.get_recent_interactions(hcp_id)
topics = be.get_topic_interests(hcp_id)
inquiries = be.get_inquiries(hcp_id)
congress = be.get_congress(hcp_id)
pubs = be.get_publications(hcp_id)
shared = be.get_content_shared(hcp_id)
nbe = be.get_next_best(hcp_id)
rec = be.recommend_content(hcp_id)

# ------------------------------------------------------------- header row ---
c1, c2, c3, c4 = st.columns(4)
c1.metric("Influence Score", f"{profile.get('influence_score', 0):.0f}")
c2.metric("Engagement Score", f"{profile.get('engagement_score', 0):.0f}")
c3.metric("Educational Need", f"{profile.get('educational_need_score', 0):.0f}")
days = profile.get("days_since_last_msl", 999)
c4.metric("Days Since Last MSL", "—" if days == 999 else f"{days:.0f}")

# ============================================================ AI BRIEFING ===
st.subheader("AI-generated pre-engagement briefing")

def build_context():
    lines = []
    lines.append(f"HCP: {profile['hcp_name']}, {profile['specialty']}, {profile['practice_setting']} setting.")
    lines.append(f"Institution: {profile['institution']} ({profile['city']}, {profile['state']}, {profile['territory']}).")
    lines.append(f"Tier: {profile['hcp_tier']}. Primary therapeutic area: {profile['primary_therapeutic_area']}. "
                 f"Influence score {profile.get('influence_score',0)}, publications {profile.get('publication_count',0)}, "
                 f"trials {profile.get('trial_participation',0)}.")
    lines.append(f"Engagement: {profile.get('msl_interactions',0)} MSL interactions; "
                 f"{profile.get('interactions_90d',0)} in last 90 days; "
                 f"last MSL {'never' if days==999 else str(int(days))+' days ago'}; "
                 f"email open rate {profile.get('email_open_rate') or 0}.")
    if topics:
        tp = ", ".join(f"{t['topic_category']} (score {t['topic_interest_score']:.0f})" for t in topics[:4])
        lines.append(f"Top scientific interests: {tp}.")
    emerging = profile.get("emerging_topics")
    if emerging:
        lines.append(f"Emerging interest topics: {emerging}.")
    if interactions:
        i = interactions[0]
        lines.append(f"Most recent MSL note ({fmt_date(i['interaction_date'])}, {i['channel']}): "
                     f"topic '{i['scientific_topic']}', need '{i['information_need']}', "
                     f"sentiment {i['sentiment']}, interest {i['interest_level']}, "
                     f"follow-up requested: {i['follow_up_requested']}, "
                     f"evidence requested: {i['evidence_type_requested']}"
                     + (f", competitor: {i['competitor_mentioned']}" if i.get('competitor_mentioned') and i['competitor_mentioned']!='None' else "") + ".")
    if congress and congress.get("sessions_attended"):
        lines.append(f"Congress: attended {congress['sessions_attended']} session(s) across "
                     f"{congress['distinct_events']} event(s); last {fmt_date(congress['last_congress_date'])}.")
    open_inq = [q for q in inquiries if q['response_status'] == 'Open']
    if open_inq:
        lines.append(f"Open medical inquiries: " + "; ".join(f"{q['inquiry_topic']} ({q['indication']})" for q in open_inq[:3]) + ".")
    if shared:
        lines.append(f"Approved content previously shared: " + "; ".join(s['content_title'] for s in shared[:3]) + ".")
    else:
        lines.append("No approved content shared yet.")
    lines.append(f"Outstanding follow-ups requested: {profile.get('follow_ups_requested',0)}.")
    return "\n".join(lines)

if gen:
    with st.spinner("Generating briefing with ai_query on Databricks LLM endpoint…"):
        try:
            briefing = be.generate_briefing(build_context())
            st.session_state[f"brief_{hcp_id}"] = briefing
        except Exception as e:
            st.error(f"Briefing generation failed: {e}")

brief = st.session_state.get(f"brief_{hcp_id}")
if brief:
    st.markdown(f'<div class="mec-brief">{brief}</div>', unsafe_allow_html=True)
else:
    st.info("Click **Generate AI briefing** in the sidebar to produce the narrative summary for this HCP.")

# ===================================================== SUGGESTED PLAN =======
st.subheader("Suggested engagement plan")
pc1, pc2 = st.columns([3, 2])
with pc1:
    topic = (nbe or {}).get("topic") or (topics[0]['topic_category'] if topics else "Scientific exchange")
    trigger = (nbe or {}).get("trigger") or "Scientific engagement cadence"
    channel = profile.get("preferred_engagement_channel", "In-person")
    timing = profile.get("recommended_follow_up_window", "Within 30 days")
    asset = rec['content_title'] if rec else "MSL to identify approved asset"
    objective = (nbe or {}).get("suggested_engagement") or "Address outstanding scientific question"
    st.markdown(f"""
<div class="mec-plan">
<b>Objective:</b> {objective}<br>
<b>Trigger:</b> {trigger}<br>
<b>Topic:</b> {topic}<br>
<b>Supporting asset:</b> {asset}<br>
<b>Preferred channel:</b> {channel}<br>
<b>Timing:</b> {timing}<br>
<b>Required review:</b> MSL confirmation
</div>
""", unsafe_allow_html=True)
with pc2:
    if rec:
        st.markdown(f"""
<div class="mec-card">
<div class="mec-label">Recommended approved content</div>
<b>{rec['content_title']}</b><br>
<span class="mec-label">Type</span> {rec['content_type']} ·
<span class="mec-label">Topic</span> {rec['topic_category']}<br>
<span class="mec-label">Indication</span> {rec['indication']} ·
<span class="mec-label">Product</span> {rec['product']}<br>
<span class="mec-label">Status</span> ✅ {rec['approval_status']} ·
<span class="mec-label">Med review</span> {rec['med_review_id']}
</div>
""", unsafe_allow_html=True)
    else:
        st.markdown('<div class="mec-card">No unshared approved asset matched the top interest — '
                    'MSL to select content.</div>', unsafe_allow_html=True)

st.markdown('<div class="mec-gov">🔒 <b>Governance:</b> This recommendation is not a black box. '
            'It is derived from the HCP\'s recent MSL notes, medical inquiries, congress activity and topic-interest '
            'scores shown below, and only surfaces <b>medically approved</b> content (with review ID). '
            'It is a recommendation for MSL review — not an automated action, and not a promotional/sales recommendation.</div>',
            unsafe_allow_html=True)

# ===================================================== EVIDENCE PANELS ======
st.divider()
st.subheader("Supporting evidence — HCP 360")

col_a, col_b = st.columns(2)

with col_a:
    st.markdown("**Profile**")
    st.markdown(f"""
<div class="mec-card">
{profile['hcp_name']} · {profile['specialty']}<br>
{profile['institution']}<br>
{profile['city']}, {profile['state']} · {profile['territory']} · {profile['practice_setting']}<br>
{pill(profile['hcp_tier'])} Influence {profile.get('influence_score',0):.0f} ·
Pubs {profile.get('publication_count',0)} · Trials {profile.get('trial_participation',0)}
</div>
""", unsafe_allow_html=True)

    st.markdown("**Top scientific interests**")
    if topics:
        st.dataframe(
            [{"Topic": t["topic_category"], "Interest": round(t["topic_interest_score"]),
              "Mentions": t["mentions"], "30d vs prior": (t["mentions_current_30d"] - t["mentions_prior_30d"])}
             for t in topics],
            hide_index=True, use_container_width=True)
    else:
        st.caption("No extracted topics yet.")

    st.markdown("**Recent medical inquiries**")
    if inquiries:
        st.dataframe(
            [{"Date": fmt_date(q["inquiry_date"]), "Topic": q["inquiry_topic"],
              "Indication": q["indication"], "Status": q["response_status"],
              "Overdue": "⚠️" if q["overdue"] else ""} for q in inquiries],
            hide_index=True, use_container_width=True)
    else:
        st.caption("No inquiries on record.")

with col_b:
    st.markdown("**Recent MSL interactions**")
    if interactions:
        st.dataframe(
            [{"Date": fmt_date(i["interaction_date"]), "Channel": i["channel"],
              "Topic": i["topic_category"], "Sentiment": i["sentiment"],
              "Follow-up": "✅" if i["follow_up_requested"] else "—"} for i in interactions],
            hide_index=True, use_container_width=True)
    else:
        st.caption("No MSL interactions on record.")

    st.markdown("**Congress participation**")
    if congress and congress.get("sessions_attended"):
        st.markdown(f"""
<div class="mec-card">
Sessions attended: <b>{congress['sessions_attended']}</b> ·
Events: {congress['distinct_events']} · Booth visits: {congress['booth_visits']}<br>
Last congress: {fmt_date(congress['last_congress_date'])}
</div>
""", unsafe_allow_html=True)
    else:
        st.caption("No congress activity on record.")

    st.markdown("**Publications & clinical trials**")
    if pubs:
        st.dataframe(
            [{"Type": p["record_type"], "Title": p["title"], "Year": p["year"],
              "Venue": p["journal_or_registry"]} for p in pubs],
            hide_index=True, use_container_width=True)
    else:
        st.caption("None tracked.")

st.markdown("**Approved content previously shared**")
if shared:
    st.dataframe(
        [{"Date": fmt_date(s["shared_date"]), "Content": s["content_title"],
          "Type": s["content_type"], "Topic": s["topic_category"],
          "By": s["shared_by_msl"], "Channel": s["share_channel"]} for s in shared],
        hide_index=True, use_container_width=True)
else:
    st.caption("No approved content shared with this HCP yet.")

st.caption("Medical Omnichannel Intelligence · Databricks demo · _sa701.moe · synthetic data")
