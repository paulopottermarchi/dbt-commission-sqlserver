# dentalpar-commission-pipeline

dbt + SQL Server pipeline for debt collection commission calculation — auto-corrects import errors, matches payments to invoices, and exports to Google Sheets.

---

## Problem

Dentalpar's invoices arrive with corrupted due dates from the import system — day and month fields are swapped (`04.08.2026` instead of `08.04.2026`). On top of that, payment records have no direct link to individual invoices, making commission calculation unreliable.

This pipeline solves both problems automatically:
- Detects and corrects inverted dates by cross-referencing the `Competencia` field
- Matches each payment to the correct invoice using sequential ordering
- Calculates commission per DPD band from the client's commission table
- Exports results to Google Sheets with no cloud infrastructure cost

---

## Architecture
SQL Server (source)

│

▼

┌─────────────────────────────┐

│         STAGING             │

│  stg_casos_516              │  Filter client 516 cases

│  stg_invoice_raw            │  Extract fields from free-text description

└─────────────┬───────────────┘

│

▼

┌─────────────────────────────┐

│       INTERMEDIATE          │

│  int_invoice_base           │  Date conversion + inversion fix

│  int_invoice_dedup          │  Deduplicate by codigo_titulo (keep DPD ≥ 0)

│  int_devedores              │  CPF/CNPJ classification

│  int_ptp                    │  Latest PTP per case

│  int_comissao               │  Active commission bands

│  int_pagamentos             │  Current month payments

│  int_invoice_agregada       │  Aggregate by invoice + DPD + phase

│  int_total_pago_dia         │  Daily paid total (for proportional split)

│  int_invoice_payment        │  Sequential payment ↔ invoice matching

└─────────────┬───────────────┘

│

▼

┌─────────────────────────────┐

│           MARTS             │

│  fct_comissionamento_516    │  Final fact table with commission values

└─────────────┬───────────────┘

│

▼

Google Sheets export

(exportar_sheets.py)

---

## Key Technical Decisions

**Date inversion detection**
The import system occasionally writes dates in `mm.dd.yyyy` instead of `dd.mm.yyyy`. The pipeline detects this by comparing the month segment of `Vencimento` against `Competencia` — if they diverge, it swaps day and month. If `Vencimento` is missing entirely, it falls back to inverting `Competencia` itself.

**Sequential payment matching**
`vw_cases_payment_information` has no `invoice_id` column — payments are only linked to cases. The pipeline ranks payments chronologically and invoices by `invoice_number` within each case, then matches them positionally (1st payment → 1st paid invoice, 2nd → 2nd, etc.).

**Proportional capital split**
When multiple invoices from the same case are updated on the same day (negotiated discount), the `payed_capital` is distributed proportionally based on each invoice's `valor_pago` share of the day's total.

**Commission calculation**
`dpd_final` is computed via `DATEDIFF` from the corrected due date to today, then joined against `client_settings_commission_by_dpd` to fetch the applicable `commission_rate`. `valor_comissao = payed_capital_proporcional × commission_rate`.

---

## Stack

| Layer | Technology |
|---|---|
| Transformation | dbt Core |
| Database | SQL Server (T-SQL) |
| Orchestration | Manual / CLI |
| Export | Python + gspread |
| Output | Google Sheets |

---

## Project Structure
dbt_comissao_516/

├── dbt_project.yml

├── profiles.yml

├── exportar_sheets.py

└── models/

├── staging/

│   ├── sources.yml

│   ├── stg_casos_516.sql

│   └── stg_invoice_raw.sql

├── intermediate/

│   ├── int_invoice_base.sql

│   ├── int_invoice_dedup.sql

│   ├── int_devedores.sql

│   ├── int_ptp.sql

│   ├── int_comissao.sql

│   ├── int_pagamentos.sql

│   ├── int_invoice_agregada.sql

│   ├── int_total_pago_dia.sql

│   └── int_invoice_payment.sql

└── marts/

└── fct_comissionamento_516.sql

---

## Setup

### 1. Install dependencies

```bash
pip install dbt-sqlserver pyodbc pandas gspread google-auth
```

### 2. Configure SQL Server connection

Edit `profiles.yml` and set your server address:

```yaml
server: YOUR_SERVER   # e.g. 192.168.1.100
```

Copy the file to `C:\Users\YOUR_USERNAME\.dbt\profiles.yml`.

### 3. Configure Google Sheets API

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create a project → APIs & Services → Enable **Google Sheets API** and **Google Drive API**
3. Credentials → Create Credentials → **Service Account** → download JSON as `credentials.json`
4. Create a Google Sheet → share it with the service account email
5. Copy the spreadsheet ID from the URL into `exportar_sheets.py`

### 4. Configure exportar_sheets.py

```python
SERVER         = 'YOUR_SERVER'
SPREADSHEET_ID = 'YOUR_SPREADSHEET_ID'
```

---

## Usage

```bash
# Test connection
dbt debug

# Run full pipeline
dbt run

# Export to Google Sheets
python exportar_sheets.py

# Run everything in one command
dbt run && python exportar_sheets.py
```

---

## Output

The exported Google Sheet contains two tabs:

**Comissionamento** — full detail per invoice including corrected due date, DPD, phase band (A–O), matched payment, proportional capital, commission rate, and commission value.

**Resumo por Fase** — aggregated totals by DPD band showing invoice count, total paid capital, commission rate, and total commission value with a grand total row.

---

## Related Projects

- [Debt-Collection-Analytics-BI](https://github.com/paulopottermarchi/Debt-Collection-Analytics-BI) — Power BI star schema with 6 fact tables for debt collection analytics
- [invoice-data-quality-pipeline](https://github.com/paulopottermarchi/invoice-data-quality-pipeline) — data quality pipeline for invoice anomaly detection
