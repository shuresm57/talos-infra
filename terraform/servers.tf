# nat vm
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

# control planes

resource "hcloud_server" "cp_servers" {
  count       = 2 # should be set to 3 when that many are available on hetzner
  name        = "${var.project_name}-cp-${count.index + 1}"
  image       = var.talos_image_id
  server_type = var.server_type
  location    = var.location
  user_data   = file("../../talos/controlplane.yaml")

  labels = {
    type = "control_plane"
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
}

resource "hcloud_server_network" "cp_network" {
  count      = 2
  server_id  = hcloud_server.cp_servers[count.index].id
  network_id = hcloud_network.main.id
}

# worker node

resource "hcloud_server" "worker_node" {
  name        = "${var.project_name}-worker-1"
  image       = var.talos_image_id
  server_type = var.server_type
  location    = var.location
  user_data   = file("../../talos/worker.yaml")

  labels = {
    type = "worker_node"
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
