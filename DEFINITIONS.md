# Tech Stack Definitions

This is a living reference document to help myself to better understand the stack behind the technology. Each entry is to be written as simple as possible for my own understanding.

**Kubernetes**

A cluster of nodes, managed by a control plane, so that if a node crashes, the control plane will automatically spin up a new instance of the container as a failsafe.

**etcd**

A database that stores the entire state of your cluster so the control plane knows what everything looked like if it ever restarts.

**Quorum**

Why you need an odd number of control plane nodes, so etcd can always reach a majority vote. 3 is the minimum, you can lose 1 and still function.

**NAT (Network Address Translation) VM**

A mask your private cluster wears to access the internet, so the internet only ever sees the NAT VM's IP and never your nodes.

**CNI (Container Network Interface) - Cilium**

The virtual network connecting all containers across all nodes, replacing both the default CNI and kube-proxy using eBPF, which runs directly in the Linux Kernel.

**CSI (Container Storage Interface)**

Creates persistent storage for containers so that if a container gets dropped, the data doesn't.

**CCM (Cloud Controller Manager)**

Automates what I was doing manually with `hcloud load-balancer create` so when an app needs a public load balancer, Hetzner creates one automatically.

~~**Ingress-nginx** (deprecated)~~ 

~~The HTTP router which sits in front of all your services and routes incoming requests to the right one based on the hostname.~~

**Gateway API**

The HTTP router that replaces ingress-nginx. Routes the incoming HTTP requests to the right service based on hostname and path, just like ingress-nginx did, but by using standardized resources instead of a 3rd party controller.

Since we already Cilium as our CNI, it handles Gateway API natively with no extra components needed.

Gateway API is future proof, since it is still managed and developed upon. Ingress-nginx is frozen by Kubernetes and should therefore not be used anymore.

**Helm**

Package manager for Kubernetes that lets you install and configure applications with a command instead of writing all the yaml yourself.
