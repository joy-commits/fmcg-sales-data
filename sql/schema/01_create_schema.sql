-- ============================================================================
-- FMN Data Platform: Star Schema DDL
-- Target: Supabase Postgres
-- Run this once to create the raw + warehouse schemas before the ETL loads.
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS raw;        -- 1:1 landing zone mirroring source sheets
CREATE SCHEMA IF NOT EXISTS warehouse;  -- star schema (dims + facts) consumed by dbt/BI
CREATE SCHEMA IF NOT EXISTS meta;       -- pipeline control / audit tables

-- ----------------------------------------------------------------------------
-- META: load control + data quality audit tables
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meta.etl_load_log (
    load_id         BIGSERIAL PRIMARY KEY,
    table_name      TEXT NOT NULL,
    load_started_at TIMESTAMP NOT NULL DEFAULT now(),
    load_ended_at   TIMESTAMP,
    rows_extracted  INT,
    rows_inserted   INT,
    rows_updated    INT,
    rows_rejected   INT,
    status          TEXT CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    error_message   TEXT
);

CREATE TABLE IF NOT EXISTS meta.data_quality_log (
    dq_id         BIGSERIAL PRIMARY KEY,
    load_id       BIGINT REFERENCES meta.etl_load_log(load_id),
    table_name    TEXT NOT NULL,
    rule_name     TEXT NOT NULL,
    rows_affected INT NOT NULL,
    detail        TEXT,
    logged_at     TIMESTAMP NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- RAW: near-verbatim landing tables (light typing only, no business logic)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS raw.transactions (
    transaction_id      TEXT,
    transaction_date    DATE,
    product_id          TEXT,
    distributor_id      TEXT,
    salesperson_id      TEXT,
    quantity            INT,
    unit_price_ngn      NUMERIC,
    discount_pct        NUMERIC,
    discount_amount_ngn NUMERIC,
    revenue_ngn         NUMERIC,
    cogs_ngn            NUMERIC,
    gross_profit_ngn    NUMERIC,
    payment_method      TEXT,
    delivery_status     TEXT,
    transaction_status  TEXT,
    notes               TEXT,
    _loaded_at          TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.products (
    product_id     TEXT,
    product_name   TEXT,
    category       TEXT,
    unit_price_ngn NUMERIC,
    unit_cost_ngn  NUMERIC,
    pack_size      INT,
    is_active      BOOLEAN,
    _loaded_at     TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.distributors (
    distributor_id   TEXT,
    distributor_name TEXT,
    region           TEXT,
    city             TEXT,
    outlet_type      TEXT,
    onboarding_date  DATE,
    is_active        BOOLEAN,
    _loaded_at       TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.salespersons (
    salesperson_id     TEXT,
    salesperson_name   TEXT,
    region             TEXT,
    team               TEXT,
    hire_date          DATE,
    monthly_target_ngn NUMERIC,
    _loaded_at         TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.monthly_targets (
    record_id          TEXT,
    salesperson_id     TEXT,
    year               INT,
    month              INT,
    region             TEXT,
    target_revenue_ngn NUMERIC,
    actual_revenue_ngn NUMERIC,
    achievement_pct    NUMERIC,
    _loaded_at         TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.date_table (
    date          DATE,
    year          INT,
    quarter       INT,
    month         INT,
    month_name    TEXT,
    week          INT,
    day_of_week   TEXT,
    is_weekend    BOOLEAN,
    is_month_end  BOOLEAN,
    _loaded_at    TIMESTAMP DEFAULT now()
);

-- ----------------------------------------------------------------------------
-- WAREHOUSE: star schema (dims + facts) -- this is what dbt / BI tools read
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS warehouse.dim_date (
    date_key     DATE PRIMARY KEY,
    year         INT NOT NULL,
    quarter      INT NOT NULL,
    month        INT NOT NULL,
    month_name   TEXT NOT NULL,
    week         INT NOT NULL,
    day_of_week  TEXT NOT NULL,
    is_weekend   BOOLEAN NOT NULL,
    is_month_end BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS warehouse.dim_product (
    product_key    BIGSERIAL PRIMARY KEY,
    product_id     TEXT NOT NULL UNIQUE,
    product_name   TEXT NOT NULL,
    category       TEXT NOT NULL,
    unit_price_ngn NUMERIC NOT NULL,
    unit_cost_ngn  NUMERIC NOT NULL,
    pack_size      INT,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS warehouse.dim_distributor (
    distributor_key   BIGSERIAL PRIMARY KEY,
    distributor_id    TEXT NOT NULL UNIQUE,
    distributor_name  TEXT NOT NULL,
    region            TEXT NOT NULL,
    city              TEXT,
    outlet_type       TEXT,
    onboarding_date   DATE,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at        TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS warehouse.dim_salesperson (
    salesperson_key    BIGSERIAL PRIMARY KEY,
    salesperson_id     TEXT NOT NULL UNIQUE,
    salesperson_name   TEXT NOT NULL,
    region             TEXT NOT NULL,
    team               TEXT,
    hire_date          DATE,
    monthly_target_ngn NUMERIC,
    updated_at         TIMESTAMP NOT NULL DEFAULT now()
);

-- Fact: one row per transaction line
CREATE TABLE IF NOT EXISTS warehouse.fact_transactions (
    transaction_id         TEXT PRIMARY KEY,  -- natural key, drives upsert / incremental load
    date_key               DATE NOT NULL REFERENCES warehouse.dim_date(date_key),
    product_key            BIGINT NOT NULL REFERENCES warehouse.dim_product(product_key),
    distributor_key        BIGINT NOT NULL REFERENCES warehouse.dim_distributor(distributor_key),
    salesperson_key        BIGINT NOT NULL REFERENCES warehouse.dim_salesperson(salesperson_key),
    quantity               INT NOT NULL CHECK (quantity > 0),
    unit_price_ngn         NUMERIC NOT NULL CHECK (unit_price_ngn >= 0),
    discount_pct           NUMERIC NOT NULL CHECK (discount_pct BETWEEN 0 AND 100),
    discount_amount_ngn    NUMERIC NOT NULL,
    revenue_ngn            NUMERIC NOT NULL,
    cogs_ngn               NUMERIC NOT NULL,
    gross_profit_ngn       NUMERIC NOT NULL,
    payment_method         TEXT,
    delivery_status        TEXT,
    transaction_status     TEXT NOT NULL,
    notes                  TEXT,
    is_distributor_missing BOOLEAN NOT NULL DEFAULT FALSE,  -- true when source Distributor Id was null -> mapped to UNKNOWN
    _loaded_at             TIMESTAMP NOT NULL DEFAULT now(),
    _updated_at            TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fact_txn_date ON warehouse.fact_transactions(date_key);
CREATE INDEX IF NOT EXISTS idx_fact_txn_product ON warehouse.fact_transactions(product_key);
CREATE INDEX IF NOT EXISTS idx_fact_txn_distributor ON warehouse.fact_transactions(distributor_key);
CREATE INDEX IF NOT EXISTS idx_fact_txn_salesperson ON warehouse.fact_transactions(salesperson_key);

-- Fact: one row per salesperson/month target record
CREATE TABLE IF NOT EXISTS warehouse.fact_monthly_targets (
    record_id          TEXT PRIMARY KEY,
    salesperson_key    BIGINT NOT NULL REFERENCES warehouse.dim_salesperson(salesperson_key),
    year               INT NOT NULL,
    month              INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    region             TEXT NOT NULL,
    target_revenue_ngn NUMERIC NOT NULL,
    actual_revenue_ngn NUMERIC NOT NULL,
    achievement_pct    NUMERIC NOT NULL,  -- derived: actual/target*100 (source column was 100% null)
    _loaded_at         TIMESTAMP NOT NULL DEFAULT now(),
    _updated_at        TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fact_target_sp ON warehouse.fact_monthly_targets(salesperson_key);
CREATE INDEX IF NOT EXISTS idx_fact_target_period ON warehouse.fact_monthly_targets(year, month);
