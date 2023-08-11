#!/usr/bin/env bash

cp .env.sample .env
cd infra
terraform init
terraform apply -auto-approve
echo "AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER=$(terraform output AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER)" >> ../.env
echo "AZURE_BLOB_CONNECTION_STRING=$(terraform output AZURE_BLOB_CONNECTION_STRING)" >> ../.env
echo "AZURE_BLOB_HOST=$(terraform output AZURE_BLOB_HOST)" >> ../.env
echo "AZURE_BLOB_PASSWORD=$(terraform output AZURE_BLOB_PASSWORD)" >> ../.env
cd ..
docker compose down
docker compose up -d

while true; do
    url="http://localhost:8080/health"
    response=$(curl -s "$url")
    retry_interval=5

    if [[ "$response" == *"healthy"* ]]; then
        echo "Airflow is ready."
        break
    else
        echo "Airflow is not ready yet. Retrying in $retry_interval seconds..."
        sleep $retry_interval
    fi
done

USERNAME=$(grep '_AIRFLOW_WWW_USER_USERNAME=' .env | cut -d '=' -f2)
PASSWORD=$(grep '_AIRFLOW_WWW_USER_PASSWORD=' .env | cut -d '=' -f2)
echo "Open http://localhost:8080/"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"