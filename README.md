# Airflow sample

TBD

## Create infrastructure

1. Open command line and navigate to directory containing the infra code: `cd src/infra`
2. Login into your Azure subscription: `az login`
3. Init terraform: `terraform init`
4. Provision infrastructure: `terraform apply`
5. Use the output of the command above in your `.env` file as value for the environment variable named `AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER`

## Building via docker compose

To start application

```bash
cd src
docker compose up --build -d
```

To stop and delete containers, execute

```bash
docker compose down
```

To stop and delete containers and cached Docker images, execute

```bash
docker compose down --rmi all
```

To stop and delete containers, cached Docker images and volumes (containing cached SQL data and logs), execute

```bash
docker compose down --volumes --rmi all
```
