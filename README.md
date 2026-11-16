# CVM Funds & FIDC Analytics

Analytics engineering project over Brazilian investment fund data published by
CVM (Comissão de Valores Mobiliários), with a focus on FIDCs (Fundos de
Investimento em Direitos Creditórios — receivables funds).

> **Status:** project scaffold. The dbt project builds end-to-end on DuckDB with a
> placeholder model; real CVM models arrive in the next phases.

## Problem

CVM publishes rich open data about funds — registry (cadastro), daily NAV and
flows (informe diário), and the monthly FIDC report (informe mensal de FIDC) —
as large CSV/ZIP files with shifting layouts over time. Answering simple
questions ("how did FIDC net equity, subordination and delinquency evolve?",
"which funds changed administrator or class?") requires repeatable ingestion,
schema normalization, slowly changing dimensions and well-tested metrics.

This project builds that pipeline with dbt, tested and documented, runnable
locally for free on DuckDB and portable to Snowflake.

## Architecture

```
dados.cvm.gov.br (CSV/ZIP, ODbL)
        │
        ▼
ingest/  ── idempotent download + manifest (future)
        │
        ├──► DuckDB (local, default, free)      ── data/duckdb/*.duckdb
        └──► Snowflake (optional) stage + COPY INTO
                 │
                 ▼
dbt/  staging (views) → intermediate (views) → marts (tables)
      snapshots for registry changes, dbt_expectations tests,
      adapter-dispatched macros for DuckDB/Snowflake
        │
        ├──► dbt docs → GitHub Pages
        └──► streamlit/ (later phase)
```

| Layer        | Purpose                                                     | Materialization |
|--------------|-------------------------------------------------------------|-----------------|
| staging      | 1:1 with source files; renaming, typing, light cleaning      | view            |
| intermediate | Joins, deduplication, layout harmonization across periods   | view            |
| marts        | Fund/FIDC facts and dimensions for analysis                  | table           |

## The CVM 175 story

CVM Resolution 175 (in force since October 2023, with a phased transition)
rewrote the regulatory framework for Brazilian investment funds. Among other
changes it introduced the **fund → class → subclass** structure, so a single
fund can now hold multiple classes with distinct policies and investors, and it
brought FIDCs under a dedicated annex.

For data this means a structural break: pre-175 files are keyed by fund CNPJ,
while post-175 files increasingly report at class level, with new columns,
renamed fields and transition-period overlaps. A central goal of this project
is modeling that transition explicitly — harmonizing both regimes into a
consistent grain, tracking registry changes with snapshots, and making the
break visible in tests and documentation rather than hiding it.

## Repository layout

```
dbt/            dbt project (models, tests, macros, seeds, snapshots)
ingest/         future ingestion scripts (download, manifest, loaders)
snowflake/      optional Snowflake setup SQL (future)
streamlit/      reserved for a later Streamlit app
data/sample/    reserved for a small versioned ODbL sample (phase 1)
data/duckdb/    local DuckDB files (gitignored)
docs/           project documentation
```

## How to run locally (DuckDB)

Requirements: Python 3.11–3.13 and [uv](https://docs.astral.sh/uv/) (recommended).

```bash
uv sync                                        # or: python -m venv .venv && .venv/bin/pip install -r requirements.txt
cp dbt/profiles.yml.example dbt/profiles.yml   # `make build` also does this if missing
make build                                     # dbt deps && dbt build --target duckdb
```

Other targets:

```bash
make parse   # dbt parse
make docs    # dbt docs generate (DuckDB)
make clean   # remove dbt artifacts and local DuckDB files
```

All dbt commands use `dbt/` as both project dir and profiles dir. The DuckDB
database is created at `data/duckdb/cvm_dev.duckdb`.

## Snowflake (optional)

A Snowflake target is defined in `dbt/profiles.yml.example`, reading every
credential from environment variables (see `.env.example`; key-pair or
password authentication). **A Snowflake trial is optional and not required to
run this repository** — DuckDB is the default and the CI target.

## Streamlit

A Streamlit app comes in a later phase. The `streamlit/` folder is reserved.

## Data and licensing

- **Code:** MIT License — see [LICENSE](LICENSE).
- **Data:** CVM open data from the [Portal de Dados Abertos da CVM](https://dados.cvm.gov.br/),
  licensed under the [Open Database License (ODbL) v1.0](https://opendatacommons.org/licenses/odbl/1-0/).
  Any data sample versioned in this repository remains under ODbL and is
  attributed to CVM. Full raw data is never committed; it is downloaded locally.
