# Banking System - Shared Infrastructure

Centralized infrastructure configuration for the Banking Microservices System, including Docker Compose orchestration, Prometheus monitoring, Grafana dashboards, and Kubernetes manifests for shared components.

## Contents

```
banking-infra/
  prometheus/
    prometheus.yml           # Prometheus scrape configuration
  grafana/
    provisioning/
      datasources/           # Prometheus datasource auto-provisioning
      dashboards/            # Dashboard provider configuration
    dashboards/
      banking-overview.json  # Pre-built Grafana dashboard
  k8s/
    namespace.yaml           # banking-system namespace
    customer-db.yaml         # Customer PostgreSQL (Deployment + Service + PVC + Secret)
    account-db.yaml          # Account PostgreSQL
    transaction-db.yaml      # Transaction PostgreSQL
    notification-db.yaml     # Notification MongoDB
    rabbitmq.yaml            # RabbitMQ broker
    prometheus.yaml          # Prometheus (ConfigMap + Deployment + Service)
    grafana.yaml             # Grafana (Deployment + Service)
    deploy-all.sh            # One-command Minikube deployment
```

## Docker Compose (Local Development)

The root-level `docker-compose.yml` starts the entire system:

```bash
cd banking-system
docker compose up --build -d
```

Services and their ports:

| Service | Port |
|---------|------|
| Customer Service | 8001 |
| Account Service | 8002 |
| Transaction Service | 8003 |
| Notification Service | 8004 |
| Customer DB (PostgreSQL) | 5433 |
| Account DB (PostgreSQL) | 5434 |
| Transaction DB (PostgreSQL) | 5435 |
| Notification DB (MongoDB) | 27017 |
| RabbitMQ AMQP | 5672 |
| RabbitMQ Management | 15672 |
| Prometheus | 9090 |
| Grafana | 3000 |

## Kubernetes Deployment

Deploy the full system to Minikube with a single script:

```bash
minikube start --cpus=4 --memory=8192
bash k8s/deploy-all.sh
```

The script builds Docker images inside Minikube, deploys all databases and infrastructure, then deploys the microservices.

## Grafana Dashboard

The pre-provisioned dashboard includes:

- Request rate per service (RPS)
- Error rate per service (4xx/5xx)
- Response latency percentiles (p50, p90, p99)
- Transaction totals and failed transfers
- Notification delivery metrics
- Daily limit exceeded rate
- Balance check latency
