from airflow import DAG
from pendulum import datetime, duration
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.operators.bash import BashOperator
from airflow.hooks.base import BaseHook
from airflow.sdk import Variable
from include.extract import extract
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

DBT_DIR = "/opt/airflow/dags/dbt_transform/fmcg_sales"
DBT_PROFILES_DIR = "/opt/airflow/dags/dbt_transform/fmcg_sales"

def task_failure_alert(context):
    """Functional alert for DAG run failure"""
    
    try:
        # Pull SMTP connection
        conn = BaseHook.get_connection("smtp_default")
        email_recipient = Variable.get("alert_email_recipient")
        smtp_user = conn.login
        smtp_pass = conn.password
        smtp_host = conn.host
        smtp_port = conn.port

    except Exception as e:
        print(f"Configuration Error: {e}")
        return

    # Capture details from the failed DAG
    dag_id = context['dag'].dag_id
    task_id = context['task_instance'].task_id
    log_url = context.get('task_instance').log_url

    subject = f"FMCG sales data pipeline ALERT: Failure in {dag_id}"
    
    html_content = f"""
    <h3>Pipeline Failure Detected</h3>
    <p><b>DAG:</b> {dag_id}</p>
    <p><b>Task:</b> {task_id}</p>
    <p><b>Logs:</b> <a href="{log_url}">View in Airflow UI</a></p>
    """

    msg = MIMEMultipart()
    msg['From'] = smtp_user
    msg['To'] = email_recipient
    msg['Subject'] = subject
    msg.attach(MIMEText(html_content, 'html'))

    # Force IPv4 to bypass Docker/ISP routing issues
    try:
        import socket
        # Resolve the hostname to an IP explicitly
        remote_host = socket.gethostbyname(smtp_host)
        server = smtplib.SMTP(remote_host, smtp_port)
        server.starttls() 
        server.login(smtp_user, smtp_pass)
        server.sendmail(smtp_user, [email_recipient], msg.as_string())
        server.quit()
        print(f"Alert sent to {email_recipient}")
    except Exception as e:
        print(f"SMTP Direct Send Failed even with IPv4: {e}")

# Default args with failure callback
args = {
    "owner": "Ufuoma",
    "retries": 0,
    "on_failure_callback": task_failure_alert,
}

# DAG definition
with DAG(
    dag_id="elt_pipeline",
    start_date=datetime(2026, 7, 6),
    default_args=args,
    catchup=False,
    max_active_runs=1
) as dag:

    extract_and_load = PythonOperator(
        task_id='extract',
        python_callable=extract
    )

    # Run silver/staging models
    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=f"cd {DBT_DIR} && dbt run --select staging --profiles-dir {DBT_PROFILES_DIR}",
    )

    # Run gold/marts models
    dbt_run_marts = BashOperator(
        task_id="dbt_run_marts",
        bash_command=f"cd {DBT_DIR} && dbt run --select marts --profiles-dir {DBT_PROFILES_DIR}",
    )

    # Test all models
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {DBT_DIR} && dbt test --profiles-dir {DBT_PROFILES_DIR}",
    )

    extract_and_load >> dbt_run_staging >> dbt_run_marts >> dbt_test
