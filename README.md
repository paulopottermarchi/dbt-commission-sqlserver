# dbt_comissao_516

Projeto dbt para cálculo de comissionamento Dentalpar (cliente 516)
com exportação automática para Google Sheets.

---

## Estrutura

```
dbt_comissao_516/
├── dbt_project.yml
├── profiles.yml
├── exportar_sheets.py
└── models/
    ├── staging/
    │   ├── sources.yml
    │   ├── stg_casos_516.sql          -- casos do cliente 516
    │   └── stg_invoice_raw.sql        -- extração de strings do description
    ├── intermediate/
    │   ├── int_invoice_base.sql       -- conversão de datas + correção inversão
    │   ├── int_invoice_dedup.sql      -- deduplicação por codigo_titulo
    │   ├── int_devedores.sql          -- CPF/CNPJ
    │   ├── int_ptp.sql                -- PTP agregado
    │   ├── int_comissao.sql           -- faixas de comissão vigentes
    │   ├── int_pagamentos.sql         -- pagamentos do mês atual
    │   ├── int_invoice_agregada.sql   -- agregação por invoice
    │   ├── int_total_pago_dia.sql     -- total pago por day
    │   └── int_invoice_payment.sql    -- match sequencial payment ↔ invoice
    └── marts/
        └── fct_comissionamento_516.sql -- tabela final com comissão
```

---

## Setup (uma vez só)

### 1. Instalar dependências

```bash
pip install dbt-sqlserver pyodbc pandas gspread google-auth
```

### 2. Configurar conexão SQL Server

Edite `profiles.yml` e troque `SEU_SERVIDOR` pelo endereço do seu SQL Server:

```yaml
server: 192.168.1.100   # ou nome do servidor
```

O profiles.yml deve ficar em `C:\Users\SEU_USUARIO\.dbt\profiles.yml`
(copie o arquivo para lá).

### 3. Configurar Google Sheets API

1. Acesse https://console.cloud.google.com
2. Crie um projeto novo (ex: "comissao-516")
3. Vá em **APIs & Services → Enable APIs**
   - Ative: **Google Sheets API**
   - Ative: **Google Drive API**
4. Vá em **Credentials → Create Credentials → Service Account**
   - Nome: comissao-516-sa
   - Baixe o JSON e salve como `credentials.json` nesta pasta
5. Crie uma planilha em https://sheets.google.com
   - Copie o ID da URL (entre /d/ e /edit)
   - Compartilhe a planilha com o e-mail do service account (aparece no JSON)

### 4. Configurar exportar_sheets.py

Edite as variáveis no topo do arquivo:

```python
SERVER         = '192.168.1.100'
SPREADSHEET_ID = '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms'
```

---

## Uso diário

### Rodar dbt + exportar (comando único)

```bash
dbt run && python exportar_sheets.py
```

### Só rodar dbt

```bash
dbt run
```

### Só exportar (sem rodar dbt novamente)

```bash
python exportar_sheets.py
```

### Testar conexão

```bash
dbt debug
```

### Ver linhagem dos models

```bash
dbt docs generate && dbt docs serve
```

---

## O que a planilha contém

**Aba "Comissionamento"** — todos os dados detalhados por invoice:
- Identificação do caso e invoice
- Capitais (original, atual, valor pago)
- Datas (competência, vencimento original, vencimento corrigido)
- DPD final e fase de antiguidade (A a O)
- Dados do pagamento (payment_id, payment_date, payed_capital)
- Taxa de comissão e valor de comissão calculado

**Aba "Resumo por Fase"** — totais agrupados por faixa de DPD:
- Quantidade de invoices por fase
- Valor pago total proporcional
- Taxa de comissão da faixa
- Valor de comissão total
- Linha de TOTAL geral

---

## Fluxo de dados

```
SQL Server (dtdi.invoice, dtdi.case, ...)
        ↓
stg_casos_516 + stg_invoice_raw       (staging)
        ↓
int_invoice_base → int_invoice_dedup  (correção de datas, deduplicação)
int_devedores, int_ptp, int_comissao  (enriquecimento)
int_pagamentos → int_invoice_payment  (match sequencial pagamento ↔ invoice)
int_total_pago_dia                    (proporção por dia)
        ↓
fct_comissionamento_516               (mart final — tabela no banco)
        ↓
exportar_sheets.py                    (Google Sheets)
```
