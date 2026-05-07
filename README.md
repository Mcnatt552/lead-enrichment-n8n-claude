# Lead Enrichment + AI Scoring — n8n + Claude

Automated B2B lead qualification pipeline. Drop raw leads into Google Sheets — get AI scores, Postgres logs, and Discord alerts for hot leads. Zero manual triage.

> **v1.1.0** — Current build uses mock enrichment data. Apollo.io live integration is on the roadmap.

---

## The Problem

Sales teams waste 5–15 hours per week manually reviewing inbound leads.
Most tools give you raw data — not a decision. Someone still has to read every row and judge fit.

## The Solution

This workflow:
- Polls Google Sheets every 5 minutes for new lead rows
- Enriches each lead with company/role context (mock data; Apollo.io planned)
- Uses Claude Sonnet to score each lead 1–100 against your ICP
- Logs every result to PostgreSQL for history and reporting
- Posts a ranked Discord embed for hot leads (score ≥ 70) — no dashboard needed

**Time to score a single lead:** ~8–12 seconds
**Typical hot lead detection rate:** 15–30% of inbound (varies by ICP)

---

## Architecture

```
Google Sheets (new row trigger, poll every 5 min)
        │
        ▼
[Mock Enrichment]  ──── Simulated company/role data
        │                (Apollo.io integration — roadmap)
        ▼
[Claude API] ──── Analyze ICP Fit → Score 1–100 + Tier
        │          model: claude-sonnet-4-6
        ├──► [Postgres]      ── Insert lead record (skipOnConflict)
        ├──► [Google Sheets] ── Append scored row to output tab
        └──► [Discord]       ── Embed alert if score ≥ 70
```

---

## Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Orchestration | n8n Cloud | Workflow automation |
| Enrichment | Mock data (Apollo.io — roadmap) | Company size, title, seniority |
| AI Scoring | Claude API (claude-sonnet-4-6) | ICP fit analysis + 1–100 score |
| Database | PostgreSQL (Supabase) | Lead + score history |
| Output | Google Sheets | Scored lead tracker for sales team |
| Alerts | Discord Webhook | Hot lead embed (score ≥ 70) |

---

## Lead Scoring Logic

Claude evaluates each lead against four dimensions:

| Dimension | Max Points | Criteria |
|---|---|---|
| Company Size | 30 pts | 201–1,000 employees = peak ICP |
| Seniority | 30 pts | C-level / VP = max · Entry-level = low |
| Email Quality | 20 pts | Verified valid email = full credit |
| Industry Fit | 20 pts | SaaS / Tech / Finance / Healthcare = best match |

**Score Tiers:**

| Tier | Range | Action |
|---|---|---|
| 🟢 Hot | 70–100 | Discord embed fired · Priority outreach |
| 🟡 Warm | 40–69 | Logged · Follow-up queue |
| 🔴 Cold | 1–39 | Logged · Deprioritized |

---

## Sample Output

```
🔥 Hot Lead Alert

Name:     Sarah Chen — VP of Sales
Company:  Acme Corp (680 employees · SaaS)
Score:    87 / 100  |  Tier: Hot
Reason:   Strong ICP fit — VP seniority, verified email,
          SaaS industry, headcount in target range.
```

---

## Setup

### Prerequisites

- n8n Cloud (or self-hosted v1.0+)
- Anthropic API key
- Supabase project (free tier works)
- Google account with Sheets access
- Discord server with a Webhook URL

### 1. Database

```sql
-- Run in Supabase SQL Editor
-- File: lead-enrichment-schema.sql
```

### 2. n8n Credentials

| Credential | Type | Notes |
|---|---|---|
| Anthropic Header Auth | Generic → Header Auth | Name: `x-api-key` · Value: your Anthropic key |
| Supabase Postgres | Postgres | Connection string from Supabase dashboard |
| Google Sheets OAuth2 | OAuth2 | Scope: spreadsheets |
| Discord Webhook | — | Paste URL directly into Discord node · No credential needed |

### 3. Import Workflow

1. n8n → **Workflows → Import from File**
2. Select `lead-enrichment-workflow.json`
3. Replace all `YOUR_*` placeholders in node settings
4. Activate the workflow

### 4. Google Sheet Structure

**Input tab** (`Leads`):

| first_name | last_name | company | domain | email *(optional)* |
|---|---|---|---|---|
| Sarah | Chen | Acme Corp | acmecorp.io | |

**Output tab** (`Scored Leads`) — auto-populated by the workflow.

---

## Error Handling

| Failure | Behavior |
|---|---|
| Missing enrichment data | Scores on available fields, no crash |
| Claude parse error | Defaults to score=0, tier=Cold, logs error |
| Postgres duplicate | `skipOnConflict=true` — silently skips |
| Missing email in input | Continues without email score dimension |

---

## Monitoring

```sql
-- Today's pipeline breakdown
SELECT tier, COUNT(*), ROUND(AVG(score), 1)
FROM leads
WHERE scored_at > NOW() - INTERVAL '24 hours'
GROUP BY tier;

-- Hot leads pending outreach
SELECT * FROM v_hot_leads LIMIT 20;
```

---

## Cost Estimate

| Service | Volume | Est. Monthly Cost |
|---|---|---|
| Claude API (claude-sonnet-4-6) | 500 leads · ~300 tokens each | ~$0.75 |
| Supabase | Free tier (500 MB) | $0 |
| n8n Cloud | Starter | $24 |
| Discord | Unlimited webhooks | $0 |
| **Total** | **500 leads/mo** | **~$25/mo** |

> Apollo.io Basic (~$49/mo) will be added when live enrichment is integrated.

---

## Roadmap

- [ ] Apollo.io live enrichment (email discovery + company data)
- [ ] HubSpot / Pipedrive write-back after scoring
- [ ] Slack alert option alongside Discord
- [ ] Webhook trigger for real-time ingest from web forms
- [ ] Monthly re-scoring for warm leads
- [ ] Clearbit as enrichment fallback

---

## Extending This Workflow

- **Custom ICP** — modify the Claude system prompt to match your exact buyer profile
- **CRM sync** — add HubSpot or Pipedrive node after the Postgres step
- **Webhook trigger** — replace the Sheets poller with a webhook for real-time form ingest
- **Re-scoring** — schedule a second workflow to re-score warm leads monthly

---

## Files

```
.
├── lead-enrichment-workflow.json   # n8n workflow import
├── lead-enrichment-schema.sql      # Postgres schema + views
└── README.md                       # This file
```

---

## Author

**Mc Natth** (Natthapakorn Suksamran) — AI Automation Engineer (Freelance)
Stack: n8n · Claude API · PostgreSQL · Google Sheets · Discord

[GitHub](https://github.com/Mcnatth552) · [LinkedIn](https://linkedin.com/in/natthapakorn-suksamran-149205204)

---

*Part of the [AI Automation Portfolio](https://github.com/Mcnatth552)*
