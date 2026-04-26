#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [[ ! -f "$ROOT_DIR/docker-compose.yml" ]] || [[ ! -d "$ROOT_DIR/banking-customer-service" ]]; then
  echo "ERROR: Could not find repo root (expected docker-compose.yml and banking-customer-service under: $ROOT_DIR)" >&2
  echo "This script must live at <repo>/banking-infra/k8s/deploy-all.sh — do not copy it elsewhere." >&2
  exit 1
fi

echo "--- Creating namespace ---"
kubectl apply -f "$SCRIPT_DIR/namespace.yaml"

echo "--- Deploying databases ---"
kubectl apply -f "$SCRIPT_DIR/customer-db.yaml"
kubectl apply -f "$SCRIPT_DIR/account-db.yaml"
kubectl apply -f "$SCRIPT_DIR/transaction-db.yaml"
kubectl apply -f "$SCRIPT_DIR/notification-db.yaml"

echo "--- Deploying RabbitMQ ---"
kubectl apply -f "$SCRIPT_DIR/rabbitmq.yaml"

echo "--- Waiting for databases and RabbitMQ to be ready ---"
kubectl -n banking-system wait --for=condition=ready pod -l app=customer-db --timeout=120s
kubectl -n banking-system wait --for=condition=ready pod -l app=account-db --timeout=120s
kubectl -n banking-system wait --for=condition=ready pod -l app=transaction-db --timeout=120s
kubectl -n banking-system wait --for=condition=ready pod -l app=notification-db --timeout=300s
kubectl -n banking-system wait --for=condition=ready pod -l app=rabbitmq --timeout=300s

echo "--- Building Docker images on the host and loading into Minikube ---"
# Building *inside* Minikube's Docker (eval "$(minikube docker-env)") often breaks when:
#   - the Minikube daemon requires a newer Docker API than the CLI reports, or
#   - the docker-buildx CLI plugin is missing (BuildKit tries to invoke it).
# Build against your normal Docker Desktop / engine, then import images into the cluster.
if command -v minikube >/dev/null 2>&1; then
  # shellcheck disable=SC2312
  eval "$(minikube docker-env -u)" 2>/dev/null || true
fi
unset DOCKER_TLS_VERIFY DOCKER_HOST DOCKER_CERT_PATH MINIKUBE_ACTIVE_DOCKERD 2>/dev/null || true
export DOCKER_BUILDKIT=0

docker build -f "$ROOT_DIR/banking-customer-service/Dockerfile" -t banking-customer-service:latest "$ROOT_DIR"
minikube image load banking-customer-service:latest

docker build -t banking-account-service:latest "$ROOT_DIR/banking-account-service"
minikube image load banking-account-service:latest

docker build -t banking-transaction-service:latest "$ROOT_DIR/banking-transaction-service"
minikube image load banking-transaction-service:latest

docker build -t banking-notification-service:latest "$ROOT_DIR/banking-notification-service"
minikube image load banking-notification-service:latest

echo "--- Deploying microservices ---"
kubectl apply -f "$ROOT_DIR/banking-customer-service/k8s/"
kubectl apply -f "$ROOT_DIR/banking-account-service/k8s/"
kubectl apply -f "$ROOT_DIR/banking-transaction-service/k8s/"
kubectl apply -f "$ROOT_DIR/banking-notification-service/k8s/"

echo "--- Deploying monitoring ---"
kubectl apply -f "$SCRIPT_DIR/prometheus.yaml"
kubectl apply -f "$SCRIPT_DIR/grafana.yaml"

echo "--- Waiting for all pods to be ready (long timeout: first Prisma migrate + JVM warm-up can be slow on Minikube) ---"
kubectl -n banking-system wait --for=condition=ready pod --all --timeout=900s

echo "--- Deployment complete ---"
kubectl -n banking-system get pods
kubectl -n banking-system get svc

echo ""
echo "Access services via:"
echo "  Customer Service:  minikube service customer-service -n banking-system --url"
echo "  Account Service:   minikube service account-service -n banking-system --url"
echo "  Transaction Service: minikube service transaction-service -n banking-system --url"
echo "  Notification Service: minikube service notification-service -n banking-system --url"
echo "  Prometheus:        minikube service prometheus -n banking-system --url"
echo "  Grafana:           minikube service grafana -n banking-system --url"
echo "  RabbitMQ Mgmt:     kubectl -n banking-system port-forward svc/rabbitmq 15672:15672"
