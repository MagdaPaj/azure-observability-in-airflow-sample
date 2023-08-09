from airflow import DAG
from airflow.operators.docker_operator import DockerOperator
from datetime import datetime
import app.config as app_config

default_args = {
    'owner': 'airflow',
    'start_date': datetime(2023, 7, 4)
}

dag = DAG(
    'hello_and_goodbye',
    default_args=default_args,
    catchup=False
)

hello_task = DockerOperator(
    task_id='hello_docker',
    image='hello:latest',
    api_version='auto',
    network_mode='airflow-sample_default',
    auto_remove=True,
    mount_tmp_dir=False,
    environment=app_config.to_dict(),
    dag=dag
)

goodbye_task = DockerOperator(
    task_id='goodbye_docker',
    image='goodbye:latest',
    api_version='auto',
    network_mode='airflow-sample_default',
    auto_remove=True,
    mount_tmp_dir=False,
    environment=app_config.to_dict(),
    dag=dag
)

hello_task >> goodbye_task
