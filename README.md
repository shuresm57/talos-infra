# Talos Infrastructure

I built a private Kubernetes cluster on Hetzner Cloud. Just raw infrastructure without managed K8s and no public IPs on any of the nodes.


## The Build

This is a production style cluster where none of the Kubernetes nodes are reachable from the internet. All outbound traffic is routed through a NAT VM and the only public entry point is a load balancer, sitting in front of the control plane.

```
Internet → Load Balancer (public IP)
                │
         Private Network (10.0.0.0/16)
         ├── nat-vm   — outbound NAT gateway
         ├── cp1      — control plane
         ├── cp2      — control plane
         ├── cp3      — control plane
         └── worker1  — worker node

```

Every node is running a distro called Talos Linux which is an API driven OS that contains no shell and therefore no SSH either.


## Why?

A setup like this on AWS or Azure would cost a lot more, for a personal cluster or a small application, this is way more favorable - not only that but it is also very compliant with organizational zero trust, since the attack surface is so small.
