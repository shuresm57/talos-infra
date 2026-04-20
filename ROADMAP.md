# Roadmap

## Done
- [x] Talos Linux cluster on Hetzner Cloud (2 control plane + 1 worker)
- [x] Private network with NAT VM for outbound internet
- [x] Hetzner Load Balancer exposing Talos API (50000) and Kubernetes API (6443)
- [x] Cilium CNI with kube-proxy replacement
- [x] Gateway API (replaced ingress-nginx)
- [x] Hetzner Cloud Controller Manager (HCCM)
- [x] Test app deployed via HTTPRoute
- [x] Deploy script (`scripts/deploy.sh`) — interactive prompts, talosctl health check, kubeconfig generation, Terraform integration

### Terraform — Hetzner Infrastructure
- [x] `versions.tf` — required Terraform version + pinned Hetzner provider
- [x] `variables.tf` — input variables (`hcloud_token`, `project_name`, `talos_image_id`, `location`, `server_type`)
- [x] `main.tf` — Hetzner provider config
- [x] `network.tf` — private network, subnet, NAT route
- [x] `servers.tf` — NAT VM, control plane nodes, worker node
- [x] `loadbalancer.tf` — load balancer in front of the control plane
- [x] `outputs.tf` — `load_balancer_ip`, `nat_vm_ip`
- [x] `.env` with `TF_VAR_*` variables sourced before `terraform apply`

---

## In Progress

### Fix `terraform plan` errors

- [ ] **`network.tf:16`** — typo `hcloud_server_network.nap.ip` → `hcloud_server_network.nat.ip`
- [ ] **`servers.tf`** — user_data paths wrong (running from `terraform/`, not `terraform/hetzner/`):
  - line 7: `../../talos/nat-vm-cloud-init.yaml` → `../talos/nat-vm-cloud-init.yaml`
  - line 23: `../../talos/controlplane.yaml` → `../talos/controlplane.yaml`
  - line 48: `../../talos/worker.yaml` → `../talos/worker.yaml`
- [ ] **`servers.tf:61`** — `hcloud_server.worker.id` → `hcloud_server.worker_node.id` (or rename resource to `worker`)

### Fix label / config mismatches

- [ ] **`servers.tf:26`** — control plane label is `type = "control_plane"` but `loadbalancer.tf:23` selects `type=cp`. Change one so they match.
- [ ] **`loadbalancer.tf:3`** — `load_balancer_type = "lbll"` looks like a typo of `lb11`.
- [ ] **`loadbalancer.tf`** — only the Talos API (50000) service is declared. Add a `hcloud_load_balancer_service` for the Kubernetes API on port `6443`.

### Remote state

- [ ] Store `terraform.tfstate` remotely so it's not lost if the local file is deleted.
  - Option A: [Terraform Cloud](https://app.terraform.io) (free tier)
  - Option B: Hetzner Object Storage S3 backend

---

### How to use

```bash
cd terraform
set -a; source ../.env; set +a
terraform init          # download the Hetzner provider
terraform validate      # check syntax
terraform plan          # preview what will be created
terraform apply         # create everything
```

After apply, use the outputs:
```bash
terraform output load_balancer_ip   # → 95.217.x.x
terraform output nat_vm_ip          # → 49.12.x.x
```

---

## Todo

### Security & TLS

- [ ] **Install cert-manager**

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true \
  --kubeconfig kubeconfig
```

- [ ] **Add HTTPS to the Gateway**
  - Create a `ClusterIssuer` using Let's Encrypt
  - Add a `443/HTTPS` listener to `main-gateway` referencing a TLS secret
  - cert-manager will provision the certificate automatically via HTTP-01 or DNS-01 challenge

---

### Observability

- [ ] **Install Prometheus + Grafana**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --kubeconfig kubeconfig
```

- [ ] Expose Grafana via an `HTTPRoute` on the gateway

---

### CI/CD

- [ ] **GitHub Actions** — apply manifests automatically on push to `main`
  - Create `.github/workflows/deploy.yml`
  - Store `kubeconfig` as a GitHub Actions secret
  - On push: run `kubectl apply -f kubernetes/` with the kubeconfig from secrets
