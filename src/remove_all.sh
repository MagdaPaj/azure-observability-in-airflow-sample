#!/usr/bin/env bash

docker compose down --volumes --rmi all
cd infra
terraform destroy -auto-approve