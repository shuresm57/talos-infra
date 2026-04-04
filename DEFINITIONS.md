**Kubernetes**

A cluster of nodes, managed by a control plane, so that if a node crashes, the control plane will automatically spin up a new instance of the container as a failsafe.

**etcd**

A database that stores the entire state of your cluster so the control plane knows what everything lookedlike if it ever restarts.

**Quorum**

Why you need an off number of control plane nodes, so etcd can always reach a majority vote. 3 is the mininum, you can lose 1 and still function.

**NAT (Network Address Translation) VM**

A mask your private cluster wears to access the internet, so the internet only ever sees the NAT VM's IP and never your nodes.

**CNI (Container Network Interface) - Cilium**

The virtual network connecting all containers accross all nodes, replacing both the default CNI and kube-proxy using eBPF, which runs directly in the Linux Kernel.

**CSI (Container Storage Interface)**

Creates persistent storage for containers so that if a container gets dropped, the data doesn't.

**CCM (Cloud Controller Manager)**

Automates what I was doing manually with `hcloud load-balancer create` so when an app needs a public load balancer, Hetzner creates one automatically.

**Ingress NGINX** (deprecated) 

The HTTP router which sits in front of all your services and routes incoming requests to the right one based on the hostname.

**Helm**

Package manager for Kubernetes that lets you install and configure applications with a command instead of writing all the yaml yourself.
