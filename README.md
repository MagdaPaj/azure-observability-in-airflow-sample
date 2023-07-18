# Airflow sample

TBD

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
