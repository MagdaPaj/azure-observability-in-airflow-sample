import logging
import os
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from datetime import datetime

default_args = {
    'owner': 'airflow',
    'start_date': datetime(2023, 7, 4)
}

dag = DAG(
    'hello',
    default_args=default_args,
    catchup=False
)

def say_hello():
    name = os.getenv("USER", '')
    logging.info(f'Hello {name} from Airflow!')

say_hello_task = PythonOperator(
    task_id='say_hello',
    python_callable=say_hello,
    dag=dag
)

say_hello_task
