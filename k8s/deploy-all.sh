#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
kubectl -n banking-system wait --for=condition=ready pod -l app=notification-db --timeout=120s
kubectl -n banking-system wait --for=condition=ready pod -l app=rabbitmq --timeout=120s

echo "--- Building and loading Docker images into Minikube ---"
eval "$(minikube docker-env)"

docker build -t banking-customer-service:latest "$ROOT_DIR/banking-customer-service"
docker build -t banking-account-service:latest "$ROOT_DIR/banking-account-service"
docker build -t banking-transaction-service:latest "$ROOT_DIR/banking-transaction-service"
docker build -t banking-notification-service:latest "$ROOT_DIR/banking-notification-service"

echo "--- Deploying microservices ---"
kubectl apply -f "$ROOT_DIR/banking-customer-service/k8s/"
kubectl apply -f "$ROOT_DIR/banking-account-service/k8s/"
kubectl apply -f "$ROOT_DIR/banking-transaction-service/k8s/"
kubectl apply -f "$ROOT_DIR/banking-notification-service/k8s/"

echo "--- Deploying monitoring ---"
kubectl apply -f "$SCRIPT_DIR/prometheus.yaml"
kubectl apply -f "$SCRIPT_DIR/grafana.yaml"

echo "--- Waiting for all pods to be ready ---"
kubectl -n banking-system wait --for=condition=ready pod --all --timeout=300s

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
