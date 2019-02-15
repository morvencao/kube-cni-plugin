# kube-cni-plugin

A simple CNI plugin for Kubernetes cluster that responsible for implementing a Kubernetes overlay network, as well as for allocating and configuring network interfaces in pods.

## Background

With [kubernetes](https://kubernetes.io/), you can easily move your workloads from virtual machines (VMs) to Kubernetes containers without any changes. To achieve the target, kubernetes provides three fundamental requirements:

- All the containers can communicate with each other directly without NAT.
- All the nodes can communicate with all containers (and vice versa) without NAT.
- The IP that a container sees itself as is the same IP that others see it as.

The main challenge in implementing these requirements is that containers can be placed to different nodes. It is relatively easy to create a virtual network on a single host (what Docker does), but spreading this network across different virtual machines or physical hosts is not a trivial task. Also, there is no single standard implementation of Kubernetes network model, Instead, the preferred implementation greatly depends on an environment where your cluster is deployed. That’s why the Kubernetes team decided to externalize the approach and redirect the task of implementing the network model to a [CNI plug-in](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/).

### CNI plugins

CNI plug-in is responsible for allocating network interfaces to the newly created containers. Kubernetes first creates a container without a network interface and then calls a CNI plug-in. The plug-in configures container networking and returns information about allocated network interfaces, IP addresses, etc. The parameters that Kubernetes sends to a CNI plugin, as well as the structure of the response must satisfy the CNI specification, but the plug-in itself may do whatever it needs to do its job.

The idea is that kube-cni allocates a subnet for each container host and then set up some kind of routing between the hosts to forward container traffic appropriately.

