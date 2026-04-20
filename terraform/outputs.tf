output "load_balancer_ip" {
  description = "Public IP of the load balancer — use for certSANs, talosctl endpoint, and DNS"
  value       = hcloud_load_balancer.apid.ipv4
}

output "nat_vm_ip" {
  description = "Public IP of the NAT VM — use to SSH in if needed"
  value       = hcloud_server.nat.ipv4_address
}