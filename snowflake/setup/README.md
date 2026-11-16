# snowflake/setup/

Optional. Setup SQL for running this project on Snowflake. Not needed for the
default DuckDB workflow, and unused until a Snowflake trial/account exists.

## Planned scripts

1. **Resource monitor** — monthly credit quota with notify/suspend triggers, to
   keep a trial within budget.
2. **Warehouse** — `X-Small`, `AUTO_SUSPEND = 60`, `AUTO_RESUME = TRUE`,
   `INITIALLY_SUSPENDED = TRUE`, attached to the resource monitor.
3. **Roles** — a transformer role for dbt (owns the analytics database) and a
   read-only reporter role for BI/Streamlit.
4. **Database and schemas** — raw landing schema plus dbt target schemas.
5. **Stage and file formats** — internal stage for CVM files; CSV file format
   with `FIELD_DELIMITER = ';'`, `ENCODING = 'ISO-8859-1'`, header skip.

## Sketch (illustrative, not executed)

```sql
-- Names are placeholders; adjust before running. No account identifiers or secrets here.
-- create resource monitor cvm_rm with credit_quota = 10
--   frequency = monthly start_timestamp = immediately
--   triggers on 80 percent do notify on 100 percent do suspend;
--
-- create warehouse cvm_wh
--   warehouse_size = 'XSMALL' auto_suspend = 60 auto_resume = true
--   initially_suspended = true resource_monitor = cvm_rm;
--
-- create role cvm_transformer;
-- create role cvm_reporter;
-- create database cvm_analytics;
-- create schema cvm_analytics.raw;
--
-- create file format cvm_analytics.raw.cvm_csv
--   type = csv field_delimiter = ';' skip_header = 1
--   encoding = 'ISO-8859-1' field_optionally_enclosed_by = '"';
-- create stage cvm_analytics.raw.cvm_stage file_format = cvm_analytics.raw.cvm_csv;
```

Credentials are supplied only through environment variables (see
`.env.example` and `dbt/profiles.yml.example`).
