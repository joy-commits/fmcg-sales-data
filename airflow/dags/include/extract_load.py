import pandas as pd
from sqlalchemy import create_engine
import os
from dotenv import load_dotenv
load_dotenv()

def extract_load():
    # Establish DB connection
    db_conn = os.getenv("DB_CONN")

    engine = create_engine(db_conn)

    # Get data
    excel_file = "fmcg_sales_data.xlsx"

    # Read all sheets
    excel = pd.ExcelFile(excel_file)

    # Loop through each sheet
    for sheet in excel.sheet_names:

        print(f"Loading {sheet}...")

        df = pd.read_excel(excel_file, sheet_name=sheet)

        # Load into PostgreSQL
        df.to_sql(
            sheet.lower(),
            engine,
            if_exists="replace",
            index=False
        )

    print("Done!")