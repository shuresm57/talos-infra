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