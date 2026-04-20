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
- [x] **`versions.tf`** — declare the required Terraform version and pin the Hetzner provider
- [x] **`variables.tf`** — declare input variables so secrets and settings are never hardcoded
- [x] **`main.tf`** — configure the Hetzner provider

---

## In Progress

### Terraform — Hetzner Infrastructure

Replace manual `hcloud` CLI commands with Terraform so the entire infrastructure can be reproduced with `terraform apply`.

**Prerequisites**
- Install Terraform: https://developer.hashicorp.com/terraform/install
- All files go in `terraform/hetzner/`

---

#### `network.tf` — create the private network, subnet, and NAT route

All nodes sit in a private network (`10.0.0.0/16`). The subnet defines the actual IP range used (`10.0.0.0/24`). The route sends all outbound traffic (`0.0.0.0/0`) through the NAT VM so the nodes can reach the internet without public IPs.

The route depends on the NAT VM being created first (in `servers.tf`), so Terraform will handle the ordering automatically.

```terraform
resource "hcloud_network" "main" {
  name     = "${var.project_name}-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

resource "hcloud_network_route" "nat" {
  network_id  = hcloud_network.main.id
  destination = "0.0.0.0/0"
  gateway     = hcloud_server_network.nat.ip
}
```

---

#### `servers.tf` — create the NAT VM, control plane nodes, and worker

Three types of server:

**NAT VM** — a small Debian 12 VM with a public IP. Its only job is to forward traffic from the private network to the internet. The `user_data` points to the cloud-init file that enables IP forwarding and sets up the iptables MASQUERADE rule.

```terraform
resource "hcloud_server" "nat" {
  name        = "${var.project_name}-nat"
  image       = "debian-12"
  server_type = "cx22"
  location    = var.location
  user_data   = file("../../talos/nat-vm-cloud-init.yaml")
}

resource "hcloud_server_network" "nat" {
  server_id  = hcloud_server.nat.id
  network_id = hcloud_network.main.id
}
```

**Control plane nodes** — run the Talos snapshot image. `count = 2` creates two identical nodes. They have no public IP — all traffic goes through the load balancer and NAT VM. The label `type = cp` is used by the load balancer to find them.

```terraform
resource "hcloud_server" "cp" {
  count       = 2
  name        = "${var.project_name}-cp-${count.index + 1}"
  image       = var.talos_image_id
  server_type = var.server_type
  location    = var.location
  user_data   = file("../../talos/controlplane.yaml")

  labels = {
    type = "cp"
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
}

resource "hcloud_server_network" "cp" {
  count      = 2
  server_id  = hcloud_server.cp[count.index].id
  network_id = hcloud_network.main.id
}
```

**Worker node** — same as control plane but uses the worker config and a different label.

```terraform
resource "hcloud_server" "worker" {
  name        = "${var.project_name}-worker-1"
  image       = var.talos_image_id
  server_type = var.server_type
  location    = var.location
  user_data   = file("../../talos/worker.yaml")

  labels = {
    type = "worker"
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
}

resource "hcloud_server_network" "worker" {
  server_id  = hcloud_server.worker.id
  network_id = hcloud_network.main.id
}
```

---

#### `loadbalancer.tf` — create the load balancer in front of the control plane

The load balancer has a public IP and forwards two TCP ports to the control plane nodes:
- **6443** — Kubernetes API (used by `kubectl`)
- **50000** — Talos API (used by `talosctl`)

It uses the label selector `type = cp` to automatically discover control plane nodes. `use_private_ip = true` means it routes through the private network.

```terraform
resource "hcloud_load_balancer" "apid" {
  name               = "${var.project_name}-lb"
  load_balancer_type = "lb11"
  location           = var.location
}

resource "hcloud_load_balancer_network" "apid" {
  load_balancer_id = hcloud_load_balancer.apid.id
  network_id       = hcloud_network.main.id
  ip               = "10.0.0.2"
}

resource "hcloud_load_balancer_service" "k8s_api" {
  load_balancer_id = hcloud_load_balancer.apid.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
}

resource "hcloud_load_balancer_service" "talos_api" {
  load_balancer_id = hcloud_load_balancer.apid.id
  protocol         = "tcp"
  listen_port      = 50000
  destination_port = 50000
}

resource "hcloud_load_balancer_target" "cp" {
  load_balancer_id = hcloud_load_balancer.apid.id
  type             = "label_selector"
  label_selector   = "type=cp"
  use_private_ip   = true
}
```

---

#### `outputs.tf` — expose useful values after `terraform apply`

Outputs print values to the terminal after apply and make them available to other tools (like the deploy script via `terraform output -raw`).

```terraform
output "load_balancer_ip" {
  description = "Public IP of the load balancer — use for certSANs, talosctl endpoint, and DNS"
  value       = hcloud_load_balancer.apid.ipv4
}

output "nat_vm_ip" {
  description = "Public IP of the NAT VM — use to SSH in if needed"
  value       = hcloud_server.nat.ipv4_address
}
```

---

#### Remote state — store `terraform.tfstate` remotely so it is not lost

By default Terraform stores state locally in `terraform.tfstate`. If this file is lost, Terraform loses track of what it created and you have to import everything manually.

- Option A: [Terraform Cloud](https://app.terraform.io) (free tier available)
- Option B: Hetzner Object Storage S3 backend

---

### How to use

```bash
cd terraform/hetzner
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
