# Phase 1 findings — CVM sources, FIDC tables and sample design

**Date researched:** 16 November 2026 (America/Sao_Paulo).  
**Scope:** read-only. Dictionaries and a few source files were downloaded to `/workspace/wheeljack/cvm-raw` (outside this repository). No ingestion code was added.  
**License of the source data:** ODbL, attributed to CVM — [Portal de Dados Abertos da CVM](https://dados.cvm.gov.br/).

This note records confirmed URLs, file layouts, the FIDC tables chosen for the MVP, the last month still published in the old layout, raw sizes, and a concrete sampling rule that keeps a continuous 2021–2026 series inside a versioned sample of about 10–20 MB.

---

## 1. Confirmed source URLs

All patterns below were confirmed live on 16 November 2026.

| Dataset | Portal page | File pattern | Dictionary |
|---|---|---|---|
| Fund daily report (Informe Diário FI) | https://dados.cvm.gov.br/dataset/fi-doc-inf_diario | Monthly zips in `https://dados.cvm.gov.br/dados/FI/DOC/INF_DIARIO/DADOS/inf_diario_fi_YYYYMM.zip` (2021-01 through 2026-11 are still in `DADOS`, not only the last 12 months). Annual history 2000–2020 in `.../DADOS/HIST/inf_diario_fi_YYYY.zip`. | https://dados.cvm.gov.br/dados/FI/DOC/INF_DIARIO/META/meta_inf_diario_fi.txt |
| Legacy fund registry (`cad_fi`) | https://dados.cvm.gov.br/dataset/fi-cad | https://dados.cvm.gov.br/dados/FI/CAD/DADOS/cad_fi.csv and `cad_fi_hist.zip` in the same folder | https://dados.cvm.gov.br/dados/FI/CAD/META/meta_cad_fi.txt (also `meta_cad_fi.zip` with history-field dictionaries) |
| CVM 175 registry (fund / class / subclass) | same `fi-cad` page | https://dados.cvm.gov.br/dados/FI/CAD/DADOS/registro_fundo_classe.zip → `registro_fundo.csv`, `registro_classe.csv`, `registro_subclasse.csv` | https://dados.cvm.gov.br/dados/FI/CAD/META/meta_registro_fundo_classe.zip |
| FIDC monthly report (Informe Mensal) | https://dados.cvm.gov.br/dataset/fidc-doc-inf_mensal | Monthly zips in `https://dados.cvm.gov.br/dados/FIDC/DOC/INF_MENSAL/DADOS/inf_mensal_fidc_YYYYMM.zip` from **2025-01 to 2026-10**. Earlier years are annual zips in `.../DADOS/HIST/inf_mensal_fidc_YYYY.zip` (2013–2024). | https://dados.cvm.gov.br/dados/FIDC/DOC/INF_MENSAL/META/meta_inf_mensal_fidc_txt.zip |

Format throughout: CSV, field delimiter `;`, encoding typically Latin-1 / ISO-8859-1. The future ingest script should convert to UTF-8 or declare the encoding in the Snowflake file format.

---

## 2. Informe Diário layouts and the last old-layout month

Every monthly zip from 2021-01 to 2026-11 was opened and classified by its CSV header (layout is detected from the header, not from the competence date).

| Period | Header (first line) | Layout |
|---|---|---|
| **2021-01 through 2023-11** (35 months) | `TP_FUNDO;CNPJ_FUNDO;DT_COMPTC;VL_TOTAL;VL_QUOTA;VL_PATRIM_LIQ;CAPTC_DIA;RESG_DIA;NR_COTST` | **v3 (old)** |
| **2023-12 through 2026-11** (36 months) | `TP_FUNDO_CLASSE;CNPJ_FUNDO_CLASSE;ID_SUBCLASSE;DT_COMPTC;VL_TOTAL;VL_QUOTA;VL_PATRIM_LIQ;CAPTC_DIA;RESG_DIA;NR_COTST` | **v4 (CVM 175)** |

**Last month still published in the old (v3) layout: November 2023 (`inf_diario_fi_202311.zip`).**

The cutoff is clean: no month before 2023-12 has been republished in v4, and no month from 2023-12 onward remains in v3. This is earlier than the official start of Informe Diário v4.0 (1 October 2024 for funds already adapted to Resolution 175). CVM has rewritten the monthly files from 2023-12 onwards in the new header; the competence date alone is not a reliable detector, but as of this date the file-level switch happens at 2023-12.

2026-11 is a partial month (file dated through 13 November 2026; 10 business days, ~4.5 MB zip versus ~11–12 MB for a full recent month).

HIST 2000–2020 was not required for the 2021–2026 sample. The proposal noted that HIST 2020 (and in particular early 2020) can lack `TP_FUNDO`; that variant stays out of the MVP sample.

---

## 3. FIDC tables chosen for the MVP

The monthly zip contains 17 tables up to 2023-09 and 18 tables from 2023-10, when `tab_X` (SCR risk ratings) appears. Column names below were read from the official dictionaries and checked against the actual CSV headers.

Only three subject areas are in the MVP. The chosen tables are:

### (a) Credit portfolio and delinquency — `tab_I` and `tab_V`

**`inf_mensal_fidc_tab_I` (balance-sheet / portfolio stocks)**

Key columns (real names):

- Portfolio and receivables: `TAB_I2_VL_CARTEIRA`, `TAB_I2A_VL_DIRCRED_RISCO`, `TAB_I2B_VL_DIRCRED_SEM_RISCO`
- Performing / delinquent (with substantial risk transfer, section I.2.a):
  - `TAB_I2A1_VL_CRED_VENC_AD` — credits to mature, performing
  - `TAB_I2A2_VL_CRED_VENC_INAD` — to mature, with delinquent instalments
  - `TAB_I2A21_VL_TOTAL_PARCELA_INAD` — total value of delinquent instalments
  - `TAB_I2A3_VL_CRED_INAD` — existing delinquent credits
  - `TAB_I2A5_VL_CRED_VENCIDO_PENDENTE` — already overdue when assigned to the fund
- The same breakdown without substantial risk transfer uses the `TAB_I2B*` twins (`TAB_I2B1_VL_CRED_VENC_AD`, `TAB_I2B2_VL_CRED_VENC_INAD`, `TAB_I2B21_VL_TOTAL_PARCELA_INAD`, `TAB_I2B3_VL_CRED_INAD`, `TAB_I2B5_VL_CRED_VENCIDO_PENDENTE`).

**`inf_mensal_fidc_tab_V` (aging of receivables)**

The official dictionary does not ship a table-level title, only field labels prefixed `(V.a)`, `(V.b)`, `(V.c)`. By the structure of Anexo A (and the parallel with section I.2.a), **tab_V is the aging book for receivables with substantial risk transfer**:

- Performing by tenor: `TAB_V_A_VL_DIRCRED_PRAZO`, `TAB_V_A1_VL_PRAZO_VENC_30` … `TAB_V_A10_VL_PRAZO_VENC_MAIOR_1080`
- Delinquency buckets: `TAB_V_B_VL_DIRCRED_INAD`, `TAB_V_B1_VL_INAD_30` … `TAB_V_B10_VL_INAD_MAIOR_1080`
- Anticipated: `TAB_V_C_VL_DIRCRED_ANTECIPADO` and tenor splits

`tab_VI` has the same aging columns for the book **without** substantial risk transfer (`TAB_VI_*`). It is useful later but is **not** required for the MVP; `tab_I` already carries the I.2.b stocks.

### (b) PDD (allowance / provision) — `tab_I`

There is no column literally named `PDD`. The provision is published as **“Provisão para Redução no Valor de Recuperação (-)”**:

- `TAB_I2A11_VL_REDUCAO_RECUP` — provision on the with-risk book
- `TAB_I2B11_VL_REDUCAO_RECUP` — provision on the without-risk book

Related provision lines also exist for other assets (`TAB_I2_COTA_FIDC`, `TAB_I2_DEBENTURE_CRI`, `TAB_I2_VL_OUTRO_ATIVO`), but the MVP credit-quality mart should use the two `*_VL_REDUCAO_RECUP` fields.

### (c) Senior / subordinated quotas and net asset value — `tab_X_2` and `tab_IV`

**`inf_mensal_fidc_tab_X_2` (quota quantity and unit value by class/series)**

- `TAB_X_CLASSE_SERIE` — free-text class/series label (senior, subordinated, mezzanine, series number). Values are not an enumerated domain; they are messy (accents, spelling, punctuation). Observed frequent values in 2026-10 include `Subclasse Senior Série 1`, `Subclasse Senior`, `Subclasse Subordinada Subordinada 1 |`, `Subclasse Subordinada Mezanino 1 | Série 1`. The staging model will need a parsed class flag (senior / mezzanine / subordinated) plus the raw label.
- `TAB_X_QT_COTA` — number of quotas
- `TAB_X_VL_COTA` — quota value

Class-level NAV is `TAB_X_QT_COTA * TAB_X_VL_COTA`. The subordination ratio is then subordinated (and mezzanine, if treated as a cushion) NAV over total class NAV.

**`inf_mensal_fidc_tab_IV` (fund-level NAV)**

- `TAB_IV_A_VL_PL` — net asset value
- `TAB_IV_B_VL_PL_MEDIO` — average NAV over the last three months

This is the fund/class total, not split by seniority. It is the control total against the sum of class NAVs from `tab_X_2`.

Optional, not in the MVP table set: `tab_X_1` (unitholder counts by `TAB_X_CLASSE_SERIE`, with `ID_SUBCLASSE` from 2023-10) and `tab_X_1_1` (unitholder counts already split into senior vs subordinated by investor type).

### FIDC layout changes (for staging, not a second “last old month” of the daily report)

- **2023-09 is the last month** in which the `tab_X_*` files (quota, unitholders, profitability, subscriptions) still use `CNPJ_FUNDO` without `TP_FUNDO_CLASSE`, and in which `tab_X` (SCR) does not exist.
- **From 2023-10:** `tab_X` (SCR ratings) is added; `tab_X_1` gains `ID_SUBCLASSE`; `tab_X_*` switch to `TP_FUNDO_CLASSE;CNPJ_FUNDO_CLASSE`.
- `tab_I`, `tab_IV` and `tab_V` in the HIST zips for **2021 through 2024 already have** `TP_FUNDO_CLASSE` and `CNPJ_FUNDO_CLASSE`. The official notice dated the FIDC rename at 6 January 2025, but the files currently on the portal for 2021–2024 have been republished with the new key names. Staging should still inspect the header of each file.

---

## 4. Raw sizes (full universe, before sampling)

Measured on 16 November 2026.

| Source | What was measured | Size |
|---|---|---|
| Informe Diário monthly zips 2021-01 … 2026-11 (71 files) | sum of zip sizes | **751.8 MB** |
| Same, uncompressed CSV | sum of member sizes | **3,327.7 MB** |
| Informe Diário 2021-01 (v3) | zip / CSV / rows / distinct CNPJ | 8.10 MB / 34.7 MB / 389,625 rows / 19,670 CNPJs (21 days) |
| Informe Diário 2025-09 (v4) | zip / CSV / rows / distinct CNPJ | 11.80 MB / 55.6 MB / 551,719 rows / 25,202 CNPJs (22 days) |
| Informe Diário 2026-11 (partial) | zip / CSV / rows / distinct CNPJ | 4.46 MB / 20.3 MB / 200,565 rows / 25,252 CNPJs (10 days, through 13 Nov 2026) |
| FIDC HIST annual zips 2021–2024 | zip sizes | 12.43 + 15.59 + 19.78 + 27.06 = **74.87 MB** |
| FIDC monthly zips 2025-01 … 2026-10 (22 files) | zip sizes | **69.97 MB** |
| FIDC 2026-10, MVP tables only, full universe | uncompressed | `tab_I` 2.79 MB (4,490 funds); `tab_IV` 0.62 MB; `tab_V` 1.43 MB; `tab_X_2` 2.14 MB (12,395 class/series rows) |
| `cad_fi.csv` (legacy registry) | file / rows | **17.92 MB** / 46,805 rows |
| `registro_fundo_classe.zip` | zip / uncompressed rows | **6.90 MB** — fundo 91,141 rows (27.2 MB), classe 37,147 (16.4 MB), subclasse 11,830 (1.86 MB) |

CSV delimiter `;`. Numeric fields in the FIDC files use a dot decimal (`1764833824.12`).

---

## 5. Sampling rule (continuous 2021–2026, within 10–20 MB)

A full 2021–2026 extract is far too large to version (~750 MB of daily zips alone). The sample is a **fixed, reproducible subset of funds**, stored as gzipped CSVs under `data/sample/`, plus a frozen identifier manifest. The 10–20 MB figure is a hard ceiling, not a target to fill.

### Identifier set (closed, versioned)

Build a frozen file `data/sample/sample_ids.csv` (CNPJ, role, reason) as follows:

1. **FIDC core (40 funds).** From `tab_IV` for 2026-10, take funds that also appear in the 2021-01 Informe Diário (116 such CNPJs were found when matching the raw CNPJ strings), ranked by `TAB_IV_A_VL_PL`, first 30. Add 10 large 2026-10 FIDCs that do **not** necessarily appear in 2021, so the sample also covers recent vintage funds. Prefer funds that have both senior and subordinated rows in `tab_X_2`.
2. **Non-FIDC funds spanning both daily layouts (40 funds).** From the last full day of a recent v4 month (e.g. 2025-09-30), take funds whose CNPJ is also present in 2021-01 (v3), ranked by `VL_PATRIM_LIQ`, excluding the FIDC set. 12,821 such CNPJs exist on that day, so the cut is well defined.
3. **Subclass examples (~5–10 classes).** Funds/classes with a non-empty `ID_SUBCLASSE` in a v4 month (207 such CNPJs in 2025-09), so the class × subclass grain can be tested.
4. **Identifier expansion.** Because CVM 175 keys daily and FIDC files by `CNPJ_FUNDO_CLASSE` (class CNPJ) while 2021 files key by `CNPJ_FUNDO` (fund CNPJ), **do not filter on a single CNPJ column**. Join the selected IDs through `registro_fundo` / `registro_classe` / `registro_subclasse` (and, where needed, `cad_fi`) and keep **every related fund, class and subclass CNPJ**. This is essential: only 59 of 4,490 FIDC CNPJs in `tab_IV` 2026-10 appear unchanged in the 2025-09 daily file.

The manifest is sorted and committed; it is the only source of truth for what belongs in the sample.

### Files to include

- Informe Diário: every month from **2021-01 to 2026-11**, rows whose `CNPJ_FUNDO` or `CNPJ_FUNDO_CLASSE` is in the expanded set. Keep the original header of each month so both layouts are present.
- FIDC MVP tables only: `tab_I`, `tab_IV`, `tab_V`, `tab_X_2`, every month from **2021-01 to 2026-10**.
- Registry: `cad_fi` rows and `registro_*` rows for the expanded set (not the full 18–25 MB registries).
- A one-line `MANIFEST.md` in `data/sample/` repeating the ODbL attribution and the selection rule.

Do not include FIDC `tab_II`, `tab_III`, `tab_VI`–`tab_IX`, or `tab_X` / `tab_X_1` / `tab_X_3+` in the versioned sample unless a later phase needs them.

### Size estimate (measured, not guessed)

A prototype filter was run on the already-downloaded months (2021-01, 2025-09, 2026-11 daily files and the 2026-10 FIDC MVP tables), gzipped at level 6, and scaled linearly across 35 v3 months + 35 full v4 months + the partial 2026-11 month, and across 70 FIDC months. Registry subset is negligible (tens of KB).

| Selection (before registry expansion) | Distinct IDs | Estimated versioned size |
|---|---|---|
| 15 FIDC + 10 funds + 5 subclass examples | 30 | **~1.4 MB** |
| 20 + 15 + 5 | 40 | **~1.8 MB** |
| 30 + 20 + 10 | 60 | **~2.5 MB** |
| 40 + 25 + 10 | 75 | **~3.0 MB** |

**Recommended rule: 40 FIDC + 40 non-FIDC + ~5–10 subclass examples, then expand through the 175 registry.** After expansion the identifier count will grow (each fund may contribute several class CNPJs), and the gzipped sample is expected to land in **roughly 4–8 MB**, comfortably inside the 10–20 MB ceiling and small enough for CI. If a later pass wants a richer sample, the same rule scaled to ~200–250 primary funds is estimated at **~12–15 MB**, still under 20 MB.

The estimate does not yet include the extra rows created by registry expansion; phase 1 ingestion should measure the actual packed size before committing `data/sample/` and trim the list if it approaches 20 MB.

### Caveats for the loader

- Match on both `CNPJ_FUNDO` and `CNPJ_FUNDO_CLASSE` (and `CNPJ_Classe` / `CNPJ_Fundo` in the 175 registry, which use a different case/spelling).
- Preserve monthly file headers; do not rewrite v3 files into v4 columns at sample-build time — staging does that.
- 2026-11 daily is incomplete by construction; document the as-of date in the sample manifest.

---

## 6. What was not done in this phase

- No ingestion script, no `data/sample/` payload, no Snowflake account or objects.
- `cad_fi_hist.zip` (~18 MB) was listed but not fully downloaded; it is a validation source for the SCD2 snapshot, not part of the versioned sample.
- FIDC HIST years before 2021 were not needed for this sample window.
