# ingest/

Ingestion code is not written yet. This folder will hold the scripts that bring
CVM open data from [dados.cvm.gov.br](https://dados.cvm.gov.br/) into the
warehouse.

## Planned behavior

- **Idempotent download:** fetch monthly/annual CSV/ZIP files for the fund
  registry (cadastro), daily reports (informe diário) and FIDC monthly reports
  (informe mensal de FIDC). Skip files whose remote size/ETag/Last-Modified and
  local SHA-256 are unchanged; re-runs never duplicate data.
- **Manifest:** a local manifest (CSV/JSON) recording source URL, file name,
  reference period, download timestamp, byte size and SHA-256 of every file,
  so loads are reproducible and auditable.
- **DuckDB loader (default):** read the downloaded files with `read_csv`
  (`;` delimiter, `latin-1` encoding as published by CVM) into raw tables in
  `data/duckdb/cvm_dev.duckdb`, which dbt sources then reference.
- **Snowflake loader (optional):** `PUT` files to an internal stage and
  `COPY INTO` raw tables using the file formats defined in `snowflake/setup/`.
- **Sample builder:** produce the deterministic CNPJ subset in `data/sample/`.

Raw downloads go to a gitignored local folder (e.g. `data/raw/`) and are never
committed.
