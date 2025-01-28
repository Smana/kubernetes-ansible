# Cilium

## IP Address Management (IPAM)

IP Address Management (IPAM) is responsible for the allocation and management of IP addresses used by network endpoints (container and others) managed by Cilium. The default mode is "Cluster Scope".

You can set the following parameters, for example: cluster-pool, kubernetes:

```yml
cilium_ipam_mode: cluster-pool
```

### Set the cluster Pod CIDRs

Cluster Pod CIDRs use the kube_pods_subnet value by default.
If your node network is in the same range you will lose connectivity to other nodes.
Defaults to kube_pods_subnet if not set.
You can set the following parameters:

```yml
cilium_pool_cidr: 10.233.64.0/18
```

When cilium_enable_ipv6 is used. Defaults to kube_pods_subnet_ipv6 if not set.
you need to set the IPV6 value:

```yml
cilium_pool_cidr_ipv6: fd85:ee78:d8a6:8607::1:0000/112
```

### Set the Pod CIDR size of a node

When cilium IPAM uses the "Cluster Scope" mode, it will pre-allocate a segment of IP to each node,
schedule the Pod to this node, and then allocate IP from here. cilium_pool_mask_size Specifies
the size allocated from cluster Pod CIDR to node.ipam.podCIDRs.
Defaults to kube_network_node_prefix if not set.

```yml
cilium_pool_mask_size: "24"
```

cilium_pool_mask_size Specifies the size allocated to node.ipam.podCIDRs from cluster Pod IPV6 CIDR. Defaults to kube_network_node_prefix_ipv6 if not set.

```yml
cilium_pool_mask_size_ipv6: "120"
```

### IP Load Balancer Pools

Cilium's IP Load Balancer Pools can be configured with the `cilium_loadbalancer_ip_pools` variable:

```yml
cilium_loadbalancer_ip_pools:
  - name: "blue-pool"
    cidrs:
      - "10.0.10.0/24"
```

For further information, check [LB IPAM documentation](https://docs.cilium.io/en/stable/network/lb-ipam/)

### BGP Control Plane

Cilium's BGP Control Plane can be enabled by setting `cilium_enable_bgp_control_plane` to `true`.:

```yml
cilium_enable_bgp_control_plane: true
```

For further information, check [BGP Peering Policy documentation](https://docs.cilium.io/en/latest/network/bgp-control-plane/bgp-control-plane-v1/)

### BGP Control Plane Resources (New bgpv2 API v1.16+)

Cilium BGP control plane is managed by a set of custom resources which provide a flexible way to configure BGP peers, policies, and advertisements.

Cilium's BGP Instances can be configured with the `cilium_bgp_cluster_configs` variable:

```yml
cilium_bgp_cluster_configs:
  - name: "cilium-bgp"
    spec:
      bgpInstances:
      - name: "instance-64512"
        localASN: 64512
        peers:
        - name: "peer-64512-tor1"
          peerASN: 64512
          peerAddress: '10.47.1.1'
          peerConfigRef:
            name: "cilium-peer"
      nodeSelector:
        matchExpressions:
          - {key: somekey, operator: NotIn, values: ['never-used-value']}
```

Cillium's BGP Peers can be configured with the `cilium_bgp_peer_configs` variable:

```yml
cilium_bgp_peer_configs:
  - name: cilium-peer
    spec:
      # authSecretRef: bgp-auth-secret
      gracefulRestart:
        enabled: true
        restartTimeSeconds: 15
      families:
        - afi: ipv4
          safi: unicast
          advertisements:
            matchLabels:
              advertise: "bgp"
        - afi: ipv6
          safi: unicast
          advertisements:
            matchLabels:
              advertise: "bgp"
```

Cillium's BGP Advertisements can be configured with the `cilium_bgp_advertisements` variable:

```yml
cilium_bgp_advertisements:
  - name: bgp-advertisements
    labels:
      advertise: bgp
    spec:
      advertisements:
        - advertisementType: "PodCIDR"
          attributes:
            communities:
              standard: [ "64512:99" ]
        - advertisementType: "Service"
          service:
            addresses:
              - ClusterIP
              - ExternalIP
              - LoadBalancerIP
          selector:
            matchExpressions:
                - {key: somekey, operator: NotIn, values: ['never-used-value']}
```

Cillium's BGP Node Config Overrides can be configured with the `cilium_bgp_node_config_overrides` variable:

```yml
cilium_bgp_node_config_overrides:
  - name: bgpv2-cplane-dev-multi-homing-worker
    spec:
    bgpInstances:
      - name: "instance-65000"
        routerID: "192.168.10.1"
        localPort: 1790
        peers:
          - name: "peer-65000-tor1"
            localAddress: fd00:10:0:2::2
          - name: "peer-65000-tor2"
            localAddress: fd00:11:0:2::2
```

For further information, check [BGP Control Plane Resources documentation](https://docs.cilium.io/en/latest/network/bgp-control-plane/bgp-control-plane-v2/)

### BGP Peering Policies (Legacy < v1.16)

Cilium's BGP Peering Policies can be configured with the `cilium_bgp_peering_policies` variable:

```yml
cilium_bgp_peering_policies:
  - name: "01-bgp-peering-policy"
    spec:
      virtualRouters:
        - localASN: 64512
          exportPodCIDR: false
          neighbors:
          - peerAddress: '10.47.1.1/24'
            peerASN: 64512
          serviceSelector:
              matchExpressions:
              - {key: somekey, operator: NotIn, values: ['never-used-value']}
```

For further information, check [BGP Peering Policy documentation](https://docs.cilium.io/en/latest/network/bgp-control-plane/bgp-control-plane-v1/#bgp-peering-policy-legacy)

## Kube-proxy replacement with Cilium

Cilium can run without kube-proxy by setting `cilium_kube_proxy_replacement`
to `strict` (< v1.16) or `true` (Cilium v1.16+ no longer accepts `strict`, however this is converted to `true` by kubespray when running v1.16+).

Without kube-proxy, cilium needs to know the address of the kube-apiserver
and this must be set globally for all Cilium components (agents and operators).
We can only use the localhost apiserver loadbalancer in this mode
whenever it uses the same port as the kube-apiserver (by default it does).

## Cilium Operator

Unlike some operators, Cilium Operator does not exist for installation purposes.
> The Cilium Operator is responsible for managing duties in the cluster which should logically be handled once for the entire cluster, rather than once for each node in the cluster.

### Adding custom flags to the Cilium Operator

You can set additional cilium-operator container arguments using `cilium_operator_custom_args`.
This is an advanced option, and you should only use it if you know what you are doing.

Accepts an array or a string.

```yml
cilium_operator_custom_args: ["--foo=bar", "--baz=qux"]
```

or

```yml
cilium_operator_custom_args: "--foo=bar"
```

You do not need to add a custom flag to enable debugging. Instead, feel free to use the `CILIUM_DEBUG` variable.

### Adding extra volumes and mounting them

You can use `cilium_operator_extra_volumes` to add extra volumes to the Cilium Operator, and use `cilium_operator_extra_volume_mounts` to mount those volumes.
This is an advanced option, and you should only use it if you know what you are doing.

```yml
cilium_operator_extra_volumes:
  - configMap:
      name: foo
    name: foo-mount-path

cilium_operator_extra_volume_mounts:
  - mountPath: /tmp/foo/bar
    name: foo-mount-path
    readOnly: true
```

## Choose Cilium version

```yml
cilium_version: v1.12.1
```

## Add variable to config

Use following variables:

Example:

```yml
cilium_config_extra_vars:
  enable-endpoint-routes: true
```

## Change Identity Allocation Mode

Cilium assigns an identity for each endpoint. This identity is used to enforce basic connectivity between endpoints.

Cilium currently supports two different identity allocation modes:

- "crd" stores identities in kubernetes as CRDs (custom resource definition).
  - These can be queried with `kubectl get ciliumid`
- "kvstore" stores identities in an etcd kvstore.

## Enable Transparent Encryption

Cilium supports the transparent encryption of Cilium-managed host traffic and
traffic between Cilium-managed endpoints either using IPsec or Wireguard.

Wireguard option is only available in Cilium 1.10.0 and newer.

### IPsec Encryption

For further information, make sure to check the official [Cilium documentation.](https://docs.cilium.io/en/stable/security/network/encryption-ipsec/)

To enable IPsec encryption, you just need to set three variables.

```yml
cilium_encryption_enabled: true
cilium_encryption_type: "ipsec"
```

The third variable is `cilium_ipsec_key`. You need to create a secret key string for this variable.
Kubespray does not automate this process.
Cilium documentation currently recommends creating a key using the following command:

```shell
echo "3 rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)) 128"
```

Note that Kubespray handles secret creation. So you only need to pass the key as the `cilium_ipsec_key` variable, base64 encoded:

```shell
echo "cilium_ipsec_key: "$(echo -n "3 rfc4106(gcm(aes)) $(echo $(dd if=/dev/urandom count=20 bs=1 2> /dev/null | xxd -p -c 64)) 128" | base64 -w0)
```

### Wireguard Encryption

For further information, make sure to check the official [Cilium documentation.](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/)

To enable Wireguard encryption, you just need to set two variables.

```yml
cilium_encryption_enabled: true
cilium_encryption_type: "wireguard"
```

Kubespray currently supports Linux distributions with Wireguard Kernel mode on Linux 5.6 and newer.

## Bandwidth Manager

Cilium's bandwidth manager supports the kubernetes.io/egress-bandwidth Pod annotation.

Bandwidth enforcement currently does not work in combination with L7 Cilium Network Policies.
In case they select the Pod at egress, then the bandwidth enforcement will be disabled for those Pods.

Bandwidth Manager requires a v5.1.x or more recent Linux kernel.

For further information, make sure to check the official [Cilium documentation](https://docs.cilium.io/en/latest/network/kubernetes/bandwidth-manager/)

To use this feature, set the following parameters:

```yml
cilium_enable_bandwidth_manager: true
```

The base infrastructure around MQ/FQ setup provided by Cilium’s bandwidth manager also allows for use of TCP BBR congestion control for Pods. BBR achieves higher bandwidths and lower latencies for Internet traffic. you can enable it by setting the following parameters:

```yaml
cilium_enable_bandwidth_manager: true
cilium_enable_bbr: true
```

> BBR for Pods requires a v5.18.x or more recent Linux kernel.

## Host Firewall

Host Firewall enforces security policies for Kubernetes nodes. It is disable by default, since it can break the cluster connectivity.

```yaml
cilium_enable_host_firewall: true
```

For further information, check [host firewall documentation](https://docs.cilium.io/en/latest/security/host-firewall/)

## Policy Audit Mode

When _Policy Audit Mode_ is enabled, no network policy is enforced. This feature helps to validate the impact of host policies before enforcing them.

```yaml
cilium_policy_audit_mode: true
```

It is disable by default, and should not be enabled in production.

## Install Cilium Hubble

k8s-net-cilium.yml:

```yml
cilium_enable_hubble: true ## enable support hubble in cilium
cilium_hubble_install: true ## install hubble-relay, hubble-ui
cilium_hubble_tls_generate: true ## install hubble-certgen and generate certificates
```

To validate that Hubble UI is properly configured, set up a port forwarding for hubble-ui service:

```shell script
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
```

and then open [http://localhost:12000/](http://localhost:12000/).

## Hubble metrics

```yml
cilium_enable_hubble_metrics: true
cilium_hubble_metrics:
  - dns
  - drop
  - tcp
  - flow
  - icmp
  - http
```

[More](https://docs.cilium.io/en/v1.9/operations/metrics/#hubble-exported-metrics)

## Upgrade considerations

### Rolling-restart timeouts

Cilium relies on the kernel's BPF support, which is extremely fast at runtime but incurs a compilation penalty on initialization and update.

As a result, the Cilium DaemonSet pods can take a significant time to start, which scales with the number of nodes and endpoints in your cluster.

As part of cluster.yml, this DaemonSet is restarted, and Kubespray's [default timeouts for this operation](../roles/network_plugin/cilium/defaults/main.yml)
are not appropriate for large clusters.

This means that you will likely want to update these timeouts to a value more in-line with your cluster's number of nodes and their respective CPU performance.
This is configured by the following values:

```yaml
# Configure how long to wait for the Cilium DaemonSet to be ready again
cilium_rolling_restart_wait_retries_count: 30
cilium_rolling_restart_wait_retries_delay_seconds: 10
```

The total time allowed (count * delay) should be at least `($number_of_nodes_in_cluster * $cilium_pod_start_time)` for successful rolling updates. There are no
drawbacks to making it higher and giving yourself a time buffer to accommodate transient slowdowns.

Note: To find the `$cilium_pod_start_time` for your cluster, you can simply restart a Cilium pod on a node of your choice and look at how long it takes for it
to become ready.

Note 2: The default CPU requests/limits for Cilium pods is set to a very conservative 100m:500m which will likely yield very slow startup for Cilium pods. You
probably want to significantly increase the CPU limit specifically if short bursts of CPU from Cilium are acceptable to you.
