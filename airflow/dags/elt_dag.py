from airflow import DAG
from airflow.providers.standard.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.hooks.base import BaseHook
from airflow.sdk import Variable
from datetime import datetime
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

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
    'owner': 'Ufuoma',
    'on_failure_callback': task_failure_alert,
    'retries': 1,
}

# DAG definition
with DAG(
    dag_id="extract_load_transform_pipeline",
    start_date=datetime(2026, 7, 6),
    schedule='@daily',
    default_args=args,
    catchup=False,
    max_active_runs=1,
    tags=['elt', 'Master DAG']
) as dag:

    # Trigger the extraction from Excel to postgres DB
    trigger_extract = TriggerDagRunOperator(
        task_id='trigger_extract_to_s3',
        trigger_dag_id='extract_to_s3',
        wait_for_completion=True,
        poke_interval=60
    )

    # Trigger transformation with dbt
    trigger_transform = TriggerDagRunOperator(
        task_id='trigger_dbt_transform',
        trigger_dag_id='dbt_transform',
        wait_for_completion=True
    )

    # The flow
    trigger_extract >> trigger_transform