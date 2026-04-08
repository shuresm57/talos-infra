# deploy.sh — Script Breakdown

**Usage:** `./scripts/deploy.sh`

The script prompts for all inputs interactively — no arguments needed.

---

## 1. Shebang and safety flags

The shebang tells the OS to run this file with bash. The `set` flags make the script fail fast instead of silently continuing after an error.

- `-e` — exit immediately if any command fails
- `-u` — treat unset variables as an error
- `-o pipefail` — if a command in a pipe fails, the whole pipe fails

```bash
#!/usr/bin/env bash
set -euo pipefail
```

---

## 2. Interactive prompts

Instead of passing arguments on the command line, the script asks the user for each value. This makes it easier to use — just run the script and answer the questions. Each prompt includes an example so the user knows what format to use. Port defaults to 80 if left empty — press Enter to accept the default. If any required field is left empty, the script exits.

```bash
read -p "Image (e.g. nginx:alpine): " IMAGE
read -p "App name (e.g. my-app): " NAME
read -p "Domain (e.g. myapp.vstov.dk): " DOMAIN
read -p "Port [80]: " PORT
PORT=${PORT:-80}

if [[ -z "$IMAGE" || -z "$NAME" || -z "$DOMAIN" ]]; then
  echo "Error: image, app name, and domain are required"
  exit 1
fi
```

---

## 3. Dependency checks

Verify that both `talosctl` and `kubectl` are installed before trying to use them. If either is not found on the PATH, the script exits with a clear error message.

```bash
for cmd in talosctl kubectl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd is not installed or not in PATH"
    exit 1
  fi
done
```

---

## 4. Terraform outputs

Instead of expecting a `kubeconfig` file to exist on disk, the script reads the load balancer IP from Terraform outputs. This ties the script to the infrastructure that Terraform created in `terraform/hetzner/`.

```bash
TERRAFORM_DIR="$(pwd)/terraform/hetzner"

if [[ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
  echo "Error: Terraform state not found. Run 'terraform apply' in terraform/hetzner/ first."
  exit 1
fi

LB_IP=$(terraform -chdir="$TERRAFORM_DIR" output -raw load_balancer_ip)
```

The load balancer IP is the same IP used as the `talosctl` endpoint and the Kubernetes API endpoint.

---

## 5. Generate kubeconfig via talosctl

Instead of expecting a static `kubeconfig` file, the script uses `talosctl` to generate a fresh one. This ensures the credentials are always current and ties the script to the Talos cluster rather than a file that could be stale or missing.

```bash
TALOSCONFIG="$(pwd)/talos/talosconfig"

if [[ ! -f "$TALOSCONFIG" ]]; then
  echo "Error: talosconfig not found at $TALOSCONFIG"
  exit 1
fi

KUBECONFIG="$(pwd)/kubeconfig"
talosctl --talosconfig "$TALOSCONFIG" --nodes "$LB_IP" kubeconfig "$KUBECONFIG"
```

---

## 6. Cluster health check

Before deploying anything, verify the cluster is healthy using `talosctl`. This catches problems like unreachable nodes or a broken control plane before the deploy fails halfway through with a confusing kubectl error.

```bash
echo "Checking cluster health..."
talosctl --talosconfig "$TALOSCONFIG" --nodes "$LB_IP" health --wait-timeout 60s
```

---

## 7. Deployment manifest

A `Deployment` tells Kubernetes to run a container from the given image and keep it running. `replicas: 1` means one instance. The `containerPort: $PORT` documents which port the container listens on.

```bash
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
```

---

## 8. Service manifest

A `Service` of type `ClusterIP` gives the Deployment a stable internal IP and DNS name inside the cluster. Without this, the HTTPRoute has nothing to route traffic to. `targetPort: $PORT` must match the `containerPort` above.

```bash
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
```

---

## 9. HTTPRoute manifest

An `HTTPRoute` tells the Gateway how to route incoming HTTP requests. `parentRefs` points to `main-gateway` which is the Cilium-managed load balancer. `hostnames` is the domain the user passed in. Any request matching that domain and the `/` path prefix gets forwarded to the Service created above.

```bash
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
```

---

## 10. Confirmation

Print a summary so the user knows what was deployed and what DNS record to create. The gateway IP is fetched live from the cluster.

```bash
echo ""
echo "Deployed $IMAGE as '$NAME'"
echo "Point DNS: $DOMAIN → $(kubectl --kubeconfig "$KUBECONFIG" get gateway main-gateway -o jsonpath='{.status.addresses[0].value}')"
```
