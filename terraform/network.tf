resource "hcloud_network" "main" {
  name     = "${var.project_name}-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu_central"
  ip_range     = "10.0.0.0/24"
}

resource "hcloud_network_route" "nat" {
  network_id  = hcloud_network.main.id
  destination = "0.0.0.0/0"
  gateway     = hcloud_server_network.nat.ip
}