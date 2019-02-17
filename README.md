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

### Deploy

1. Deploy Kubernetes cluster with [kubeadm](https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/), kubeadm is the most flexible Kubernetes installer as it allows the use of your own network plug-in.

2. Config `kubectl` to connect to the newly created cluster:

```
$ mkdir -p $HOME/.kube
$ cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ kubectl get nodes
NAME         STATUS     ROLES     AGE       VERSION
k8s-master   NotReady   master    25m       v1.11.1
k8s-worker   NotReady             9s        v1.11.1
```

As you can see from the output, both master and worker nodes are currently in the “NotReady” state, because we haven’t configured any networking plug-in yet. If you try to deploy a pod at this time, your pod will forever hang in the “Pending” state, because the Kubernetes schedule will not be able to find any “Ready” node for it. However, kubelet runs all the system components as ordinary pods.

3. Configuring the CNI plug-in

   Find out what subnets are allocated from the pod network range:
   ```
   $ kubectl describe node k8s-master | grep PodCIDR
   PodCIDR:                     10.200.0.0/24

   $ kubectl describe node k8s-worker | grep PodCIDR
   PodCIDR:                     10.200.1.0/24
   ```

   The whole pod network range (`10.200.0.0./16`) has been divided into small subnets, and each of the nodes received its own subnets. This means that the master node can use any of the `10.200.0.0–10.200.0.255` IPs for its containers, and the worker node uses `10.200.1.0–10.200.1.255` IPs.

4. Create the CNI plugin configuration file `/etc/cni/net.d/10-kube-cni-plugin.conf` on both master and worker nodes with the following content:

```
{
    "cniVersion": "0.3.0",
    "name": "k8s-pod-network",
    "type": "kube-cni",
    "network": "10.200.0.0/16",
    "subnet": "<node-cidr-range>"
}
```

5. Create network bridge on both master and worker nodes:

```
$ brctl addbr cni0
$ ip link set cni0 up
$ ip addr add <bridge-ip>/24 dev cni0
```

Note: For this example, we reserve the `10.200.0.1` IP address for the bridge on the master node and `10.200.1.1` for the bridge on the worker node.

6. Create the route that all traffic with the destination IP belonging to the pod CIDR range, local to the current node, will be redirected to the cni0 network interface:

```
$ ip route | grep cni0
10.200.0.0/24 dev cni0  proto kernel  scope link  src 10.200.0.1

$ ip route | grep cni0
10.200.1.0/24 dev cni0  proto kernel  scope link  src 10.200.1.1
```

7. Create the CNI plugin binary in `/opt/cni/bin/` directory:

```
$ mv kube-cni.sh /opt/cni/bin/
```

8. Test the CNI plugin:

   - Check status of both the master and worker nodes becomes `Ready`:
   
      ```
      kubectl get node
      NAME         STATUS     ROLES     AGE       VERSION
      k8s-master   Ready   master    25m       v1.11.1
      k8s-worker   Ready             9s        v1.11.1
      ```
   - Untaint the master node so that pods can be deployed on master node:

     ```
     $ kubectl taint nodes k8s-master node-role.kubernetes.io/master-node/k8s-master untainted
     ```

   - Deploy the sample nginx applications:

     ```
     $ kubectl apply -f nginx-deployment.yaml
     ```

### Verfify

1. Check the newly create pod get IP address:

```
$ kubectl describe pod | grep IP
IP:                 10.200.0.3
IP:                 10.200.1.3
```
