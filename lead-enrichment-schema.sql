-- ============================================================
-- Lead Enrichment + Scoring — Postgres Schema v1.2.0
-- Compatible with Supabase (PostgreSQL 15+)
-- CHANGELOG v1.1.0: Removed Hunter.io providers, updated model default to claude-sonnet-4-6
-- CHANGELOG v1.2.0: Removed all CHECK constraints (except score 0-100), dropped enrichment_log table
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- MAIN LEADS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS leads (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  first_name          TEXT        NOT NULL,
  last_name           TEXT        NOT NULL,
  company             TEXT        NOT NULL,
  domain              TEXT,
  email               TEXT        UNIQUE,

  -- Email quality (Apollo.io — reveal_personal_emails)
  email_confidence    SMALLINT    DEFAULT 0,
  email_status        TEXT,
  email_disposable    BOOLEAN     DEFAULT false,

  -- Person enrichment (Apollo.io)
  title               TEXT,
  seniority           TEXT,
  departments         TEXT,
  linkedin_url        TEXT,

  -- Company enrichment (Apollo.io)
  company_size        INTEGER,
  company_revenue     TEXT,
  company_industry    TEXT,
  company_founded     TEXT,
  company_country     TEXT,

  -- AI Scoring (Claude API)
  score               SMALLINT    CHECK (score BETWEEN 0 AND 100),
  tier                TEXT,
  reasoning           TEXT,
  fit_signals         TEXT,
  red_flags           TEXT,

  -- Metadata
  source              TEXT        DEFAULT 'google_sheet',
  enriched_at         TIMESTAMPTZ,
  scored_at           TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SCORING HISTORY — log every re-score event
-- ============================================================
CREATE TABLE IF NOT EXISTS lead_score_history (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id     UUID        NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  score       SMALLINT    NOT NULL,
  tier        TEXT        NOT NULL,
  reasoning   TEXT,
  model       TEXT        DEFAULT 'claude-sonnet-4-6',
  scored_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_leads_email        ON leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_domain       ON leads(domain);
CREATE INDEX IF NOT EXISTS idx_leads_tier         ON leads(tier);
CREATE INDEX IF NOT EXISTS idx_leads_score        ON leads(score DESC);
CREATE INDEX IF NOT EXISTS idx_leads_company      ON leads(company);
CREATE INDEX IF NOT EXISTS idx_leads_scored_at    ON leads(scored_at DESC);
CREATE INDEX IF NOT EXISTS idx_score_history_lead ON lead_score_history(lead_id);

-- ============================================================
-- TRIGGER: auto-update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_leads_updated_at
  BEFORE UPDATE ON leads
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- VIEWS — useful for n8n dashboards
-- ============================================================

-- Hot leads (score >= 70) ready for outreach
CREATE OR REPLACE VIEW v_hot_leads AS
SELECT
  id, first_name, last_name, email, title, company,
  company_industry, company_size,
  score, tier, reasoning, fit_signals, red_flags,
  linkedin_url, scored_at
FROM leads
WHERE tier = 'hot'
ORDER BY score DESC, scored_at DESC;

-- Lead funnel summary
CREATE OR REPLACE VIEW v_lead_funnel AS
SELECT
  tier,
  COUNT(*)                                         AS total,
  ROUND(AVG(score)::NUMERIC, 1)                    AS avg_score,
  COUNT(*) FILTER (WHERE email_status = 'valid')   AS valid_emails,
  COUNT(*) FILTER (WHERE email_status = 'invalid') AS invalid_emails,
  MAX(scored_at)                                   AS last_scored
FROM leads
GROUP BY tier
ORDER BY
  CASE tier WHEN 'hot' THEN 1 WHEN 'warm' THEN 2 WHEN 'cold' THEN 3 ELSE 4 END;

-- ============================================================
-- SAMPLE DATA (remove before production)
-- ============================================================
/*
INSERT INTO leads (
  first_name, last_name, company, domain, email,
  email_status, title, seniority, departments,
  company_size, company_industry,
  score, tier, reasoning
) VALUES (
  'Sarah', 'Chen', 'Acme SaaS', 'acmesaas.io', 'sarah.chen@acmesaas.io',
  'valid', 'VP of Sales', 'vp', 'Sales',
  250, 'SaaS',
  87, 'hot', 'VP-level at mid-market SaaS with verified email. Strong ICP match.'
);
*/

-- ============================================================
-- GRANTS (Supabase service_role usage)
-- ============================================================
-- GRANT ALL ON leads, lead_score_history TO service_role;
-- GRANT SELECT ON v_hot_leads, v_lead_funnel TO anon, authenticated;
