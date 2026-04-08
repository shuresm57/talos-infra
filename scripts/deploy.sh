#!/usr/bin/env bash

# exit if any command fails, unset variables are an error, if a cimmand in the pipe fails, the whole pipe fails

set -euo pipefail

# input validation, 4 arguments exactly or exit with a non-zero code

read -p "Image: " IMAGE
read -p "App name: " NAME
read -p "Domain: " DOMAIN
read -p "Port [80]: " PORT
PORT=${PORT:-80}
if [[ -z "$IMAGE" || -z "$NAME" || -z "$DOMAIN" ]]; then
  echo "Error: all fields are required"
  exit 1
fi

# check for kubectl and talosctl installation, before it is used

for cmd in talosctl kubectl; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is not installed or not in PATH"
        exit 1
    fi
done

# dont expect a kubeconfig file to exist on disk, this reads the loadbalancer IP from terraform outputs.

TERRAFORM_DIR="$(pwd)/terraform/hetzner"

if [[ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
    echo "Error: Terraform state not found. Run 'terraform apply' in terraform/hetzner/ first."
    exit 1
fi

LOADBALANCER_IP=$(terraform -chfir="$TERRAFORM_DIR" output -raw load_balancer_ip)

# generate a kubeconfig via talosctl

TALOSCONFIG="$(pwd)/talos/talosconfig"

if [[ ! -f "$TALOSCONFIG" ]]; then
  echo "Error: talosconfig not found at $TALOSCONFIG"
  exit 1
fi

KUBECONFIG="$(pwd)/kubeconfig"
talosctl --talosconfig "$TALOSCONFIG" --nodes "$LOADBALANCER_IP" kubeconfig "$KUBECONFIG"

# cluster health check

echo "Checking cluster health..."
talosctl --talosconfig "$TALOSCONFIG" --nodes "$LOADBALANCER_IP" health --wait-timeout 60s

# deployment manifest
# replicas: 1 = one instance

kubectl --kubeconfig "$KUBECONFIG" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      containers:
        - name: $NAME
          image: $IMAGE
          ports:
            - containerPort: $PORT
EOF

# service manifest

kubectl --kubeconfig "$KUBECONFIG" apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $NAME
spec:
  selector:
    app: $NAME
  ports:
    - protocol: TCP
      port: $PORT
      targetPort: $PORT
  type: ClusterIP
EOF

# HTTPRoute Manifest

kubectl --kubeconfig "$KUBECONFIG" apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: $NAME
spec:
  parentRefs:
    - name: main-gateway
  hostnames:
    - "$DOMAIN"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: $NAME
          port: $PORT
EOF

echo ""
echo "Deployed $IMAGE as '$NAME'"
echo "Point DNS: $DOMAIN → $(kubectl --kubeconfig "$KUBECONFIG" get gateway main-gateway -o jsonpath='{.status.addresses[0].value}')"