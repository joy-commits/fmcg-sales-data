import os
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect

load_dotenv()

def extract():
    """
    Extract data from the Excel workbook and load it into PostgreSQL.
    """

    # Create database connection
    db_conn = os.getenv("DB_CONN")
    engine = create_engine(db_conn)
    inspector = inspect(engine)

    # Get the path to the Excel file
    current_dir = os.path.dirname(os.path.abspath(__file__))
    excel_file = os.path.join(current_dir, "fmcg_sales_data.xlsx")

    # Read all sheets in the workbook
    excel = pd.ExcelFile(excel_file)

    # Loop through each sheet
    for sheet in excel.sheet_names:

        table_name = sheet.lower()

        print(f"Loading {table_name}")

        # Read the current sheet
        df = pd.read_excel(excel_file, sheet_name=sheet)

        # Create the table if it doesn't exist
        if not inspector.has_table(table_name):

            df.to_sql(
                table_name,
                engine,
                if_exists="fail",
                index=False
            )

            print(f"{table_name} created")

        else:

            # For transactions table (fact), append new data
            if table_name == "transactions":

                df.to_sql(
                    table_name,
                    engine,
                    if_exists="append",
                    index=False
                )

                print("New transaction records appended")

            # Skip loading for existing dimension tables
            else:

                print(f"{table_name} already exists")

    print("Data extraction and loading completed successfully")