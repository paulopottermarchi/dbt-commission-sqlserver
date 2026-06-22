"""
exportar_sheets.py
Lê fct_comissionamento_516 do SQL Server e exporta para Google Sheets.

Pré-requisitos:
    pip install pyodbc pandas gspread google-auth

Setup Google Sheets API (uma vez só):
    1. Acesse https://console.cloud.google.com
    2. Crie um projeto → APIs & Services → Enable APIs → Google Sheets API + Google Drive API
    3. Credentials → Create Credentials → Service Account → baixe o JSON
    4. Salve o JSON como credentials.json na mesma pasta deste script
    5. Crie uma planilha no Google Sheets e compartilhe com o e-mail do service account
    6. Cole o ID da planilha em SPREADSHEET_ID abaixo
"""

import pyodbc
import pandas as pd
import gspread
from google.oauth2.service_account import Credentials
from datetime import datetime

# ============================================================
# 🔥 CONFIGURAÇÃO — altere aqui
# ============================================================
SERVER         = 'SEU_SERVIDOR'               # ex: 192.168.1.100
DATABASE       = 'debthor_dbs_interface'
SPREADSHEET_ID = 'SEU_SPREADSHEET_ID'        # ID da URL do Google Sheets
CREDENTIALS_FILE = 'credentials.json'         # arquivo baixado do Google Cloud

# ============================================================
# CONEXÃO SQL SERVER (autenticação Windows)
# ============================================================
def conectar_sql():
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        f"Trusted_Connection=yes;"
    )
    return pyodbc.connect(conn_str)

# ============================================================
# EXTRAÇÃO DOS DADOS
# ============================================================
def extrair_dados():
    print("Conectando ao SQL Server...")
    conn = conectar_sql()

    query = """
        SELECT
            case_id, ref_number, client_ref_number,
            invoice_id, invoice_number,
            original_capital_total, actual_capital_total,
            valor_pago, status_pagamento,
            CONVERT(VARCHAR, competencia, 103)        AS competencia,
            CONVERT(VARCHAR, vencimento_original, 103) AS vencimento_original,
            CONVERT(VARCHAR, data_vencimento, 103)     AS data_vencimento,
            codigo_titulo, dpd_invoice, live_dpd, dpd_final, fase,
            CONVERT(VARCHAR, update_date, 103)         AS update_date,
            CONVERT(VARCHAR, promise_date, 103)        AS promise_date,
            promise_capital,
            CONVERT(VARCHAR, contact_date, 103)        AS contact_date,
            case_statute_id, persons_born_number, documento_tipo,
            payment_id,
            CONVERT(VARCHAR, payment_date, 103)        AS payment_date,
            payed_capital_original, payed_capital_proporcional,
            commission_rate, valor_comissao,
            CONVERT(VARCHAR, payment_insert_date, 103) AS payment_insert_date,
            payment_insert_time, pay_insert_filename, payment_insert_user,
            CONVERT(VARCHAR, data_carga, 103)          AS data_carga
        FROM debthor_dbs_interface.dbt_marts.fct_comissionamento_516
        ORDER BY case_id, invoice_number
    """

    print("Extraindo dados...")
    df = pd.read_sql(query, conn)
    conn.close()
    print(f"{len(df)} linhas extraídas.")
    return df

# ============================================================
# EXPORTAÇÃO PARA GOOGLE SHEETS
# ============================================================
def exportar_sheets(df):
    print("Autenticando no Google Sheets...")
    scopes = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive",
    ]
    creds  = Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=scopes)
    client = gspread.authorize(creds)

    sh = client.open_by_key(SPREADSHEET_ID)
    mes_ref = datetime.now().strftime("%m/%Y")

    # ── ABA 1: DADOS COMPLETOS ──
    aba_dados = "Comissionamento"
    try:
        ws = sh.worksheet(aba_dados)
        ws.clear()
    except gspread.WorksheetNotFound:
        ws = sh.add_worksheet(title=aba_dados, rows=len(df) + 10, cols=len(df.columns) + 2)

    print("Exportando dados completos...")
    # cabeçalho
    headers = [c.replace("_", " ").upper() for c in df.columns]
    ws.update("A1", [headers])

    # dados em batches de 500 para não estourar quota
    data = df.fillna("").astype(str).values.tolist()
    batch_size = 500
    for i in range(0, len(data), batch_size):
        batch = data[i:i + batch_size]
        start_row = i + 2
        ws.update(f"A{start_row}", batch)
        print(f"  {min(i + batch_size, len(data))}/{len(data)} linhas...")

    # formata cabeçalho
    ws.format("A1:AJ1", {
        "backgroundColor": {"red": 0.42, "green": 0.18, "blue": 0.55},
        "textFormat": {"bold": True, "foregroundColor": {"red": 1, "green": 1, "blue": 1}, "fontSize": 10},
        "horizontalAlignment": "CENTER"
    })

    # congela linha 1
    sh.batch_update({"requests": [{
        "updateSheetProperties": {
            "properties": {"sheetId": ws.id, "gridProperties": {"frozenRowCount": 1}},
            "fields": "gridProperties.frozenRowCount"
        }
    }]})

    # ── ABA 2: RESUMO POR FASE ──
    aba_resumo = "Resumo por Fase"
    try:
        ws2 = sh.worksheet(aba_resumo)
        ws2.clear()
    except gspread.WorksheetNotFound:
        ws2 = sh.add_worksheet(title=aba_resumo, rows=30, cols=6)

    print("Exportando resumo por fase...")

    df_num = df.copy()
    for col in ["payed_capital_proporcional", "valor_comissao", "commission_rate"]:
        df_num[col] = pd.to_numeric(df_num[col], errors="coerce")

    resumo = (
        df_num[df_num["valor_comissao"].notna()]
        .groupby("fase")
        .agg(
            qtd_invoices=("invoice_id", "count"),
            valor_pago_total=("payed_capital_proporcional", "sum"),
            commission_rate=("commission_rate", "first"),
            valor_comissao=("valor_comissao", "sum"),
        )
        .reset_index()
        .sort_values("fase")
    )

    resumo_headers = ["FASE", "QTD INVOICES", "VALOR PAGO TOTAL (R$)", "TAXA COMISSÃO", "VALOR COMISSÃO (R$)"]
    resumo_data    = resumo.values.tolist()
    total_row      = [
        "TOTAL",
        int(resumo["qtd_invoices"].sum()),
        round(resumo["valor_pago_total"].sum(), 2),
        "",
        round(resumo["valor_comissao"].sum(), 2),
    ]

    ws2.update("A1", [resumo_headers] + resumo_data + [total_row])

    # formata cabeçalho resumo
    ws2.format("A1:E1", {
        "backgroundColor": {"red": 0.42, "green": 0.18, "blue": 0.55},
        "textFormat": {"bold": True, "foregroundColor": {"red": 1, "green": 1, "blue": 1}, "fontSize": 10},
        "horizontalAlignment": "CENTER"
    })

    # formata linha total
    total_row_idx = len(resumo) + 2
    ws2.format(f"A{total_row_idx}:E{total_row_idx}", {
        "backgroundColor": {"red": 0.42, "green": 0.18, "blue": 0.55},
        "textFormat": {"bold": True, "foregroundColor": {"red": 1, "green": 1, "blue": 1}},
    })

    url = f"https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}"
    print(f"\n✅ Exportado com sucesso!")
    print(f"   Planilha: {url}")
    print(f"   Mês ref:  {mes_ref}")
    print(f"   Linhas:   {len(df)}")
    print(f"   Comissão total: R$ {resumo['valor_comissao'].sum():,.2f}")

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    df = extrair_dados()
    exportar_sheets(df)
