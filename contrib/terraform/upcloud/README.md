# Kubernetes on UpCloud with Terraform

Provision a Kubernetes cluster on [UpCloud](https://upcloud.com/) using Terraform and Kubespray

## Overview

The setup looks like following

```text
   Kubernetes cluster
+--------------------------+
|      +--------------+    |
|      | +--------------+  |
| -->  | |              |  |
|      | | Master/etcd  |  |
|      | | node(s)      |  |
|      +-+              |  |
|        +--------------+  |
|              ^           |
|              |           |
|              v           |
|      +--------------+    |
|      | +--------------+  |
| -->  | |              |  |
|      | |    Worker    |  |
|      | |    node(s)   |  |
|      +-+              |  |
|        +--------------+  |
+--------------------------+
```

The nodes uses a private network for node to node communication and a public interface for all external communication.

## Requirements

* Terraform 0.13.0 or newer

## Quickstart

NOTE: Assumes you are at the root of the kubespray repo.

For authentication in your  cluster you can use the environment variables.

```bash
export TF_VAR_UPCLOUD_USERNAME=username
export TF_VAR_UPCLOUD_PASSWORD=password
```

To allow API access to your UpCloud account, you need to allow API connections by visiting [Account-page](https://hub.upcloud.com/account) in your UpCloud Hub.

Copy the cluster configuration file.

```bash
CLUSTER=my-upcloud-cluster
cp -r inventory/sample inventory/$CLUSTER
cp contrib/terraform/upcloud/cluster-settings.tfvars inventory/$CLUSTER/
export ANSIBLE_CONFIG=ansible.cfg
cd inventory/$CLUSTER
```

Edit  `cluster-settings.tfvars`  to match your requirement.

Run Terraform to create the infrastructure.

```bash
terraform init ../../contrib/terraform/upcloud
terraform apply --var-file cluster-settings.tfvars \
    -state=tfstate-$CLUSTER.tfstate \
     ../../contrib/terraform/upcloud/
```

You should now have a inventory file named `inventory.ini` that you can use with kubespray.
You can use the inventory file with kubespray to set up a cluster.

It is a good idea to check that you have basic SSH connectivity to the nodes. You can do that by:

```bash
ansible -i inventory.ini -m ping all
```

You can setup Kubernetes with kubespray using the generated inventory:

```bash
ansible-playbook -i inventory.ini ../../cluster.yml -b -v
```

## Teardown

You can teardown your infrastructure using the following Terraform command:

```bash
terraform destroy --var-file cluster-settings.tfvars \
      -state=tfstate-$CLUSTER.tfstate \
      ../../contrib/terraform/upcloud/
```

## Variables

* `prefix`: Prefix to add to all resources, if set to "" don't set any prefix
* `template_name`: The name or UUID  of a base image
* `username`: a user to access the nodes, defaults to "ubuntu"
* `private_network_cidr`: CIDR to use for the private network, defaults to "172.16.0.0/24"
* `ssh_public_keys`: List of public SSH keys to install on all machines
* `zone`: The zone where to run the cluster
* `machines`: Machines to provision. Key of this object will be used as the name of the machine
  * `node_type`: The role of this node *(master|worker)*
  * `plan`: Preconfigured cpu/mem plan to use (disables `cpu` and `mem` attributes below)
  * `cpu`: number of cpu cores
  * `mem`: memory size in MB
  * `disk_size`: The size of the storage in GB
  * `additional_disks`: Additional disks to attach to the node.
    * `size`: The size of the additional disk in GB
    * `tier`: The tier of disk to use (`maxiops` is the only one you can choose atm)
* `firewall_enabled`: Enable firewall rules
* `firewall_default_deny_in`: Set the firewall to deny inbound traffic by default. Automatically adds UpCloud DNS server and NTP port allowlisting.
* `firewall_default_deny_out`: Set the firewall to deny outbound traffic by default.
* `master_allowed_remote_ips`: List of IP ranges that should be allowed to access API of masters
  * `start_address`: Start of address range to allow
  * `end_address`: End of address range to allow
* `k8s_allowed_remote_ips`: List of IP ranges that should be allowed SSH access to all nodes
  * `start_address`: Start of address range to allow
  * `end_address`: End of address range to allow
* `master_allowed_ports`: List of port ranges that should be allowed to access the masters
  * `protocol`: Protocol *(tcp|udp|icmp)*
  * `port_range_min`: Start of port range to allow
  * `port_range_max`: End of port range to allow
  * `start_address`: Start of address range to allow
  * `end_address`: End of address range to allow
* `worker_allowed_ports`: List of port ranges that should be allowed to access the workers
  * `protocol`: Protocol *(tcp|udp|icmp)*
  * `port_range_min`: Start of port range to allow
  * `port_range_max`: End of port range to allow
  * `start_address`: Start of address range to allow
  * `end_address`: End of address range to allow
* `loadbalancer_enabled`: Enable managed load balancer
* `loadbalancer_plan`: Plan to use for load balancer *(development|production-small)*
* `loadbalancer_legacy_network`: If the loadbalancer should use the deprecated network field instead of networks blocks. You probably want to have this set to false (default value)
* `loadbalancers`: Ports to load balance and which machines to forward to. Key of this object will be used as the name of the load balancer frontends/backends
  * `port`: Port to load balance.
  * `target_port`: Port to the backend servers.
  * `backend_servers`: List of servers that traffic to the port should be forwarded to.
* `router_enable`: If a router should be connected to the private network or not
* `gateways`: Gateways that should be connected to the router, requires router_enable is set to true
  * `features`: List of features for the gateway
  * `plan`: Plan to use for the gateway
  * `connections`: The connections and tunnel to create for the gateway
    * `type`: What type of connection
    * `local_routes`: Map of local routes for the connection
      * `type`: Type of route
      * `static_network`: Destination prefix of the route; needs to be a valid IPv4 prefix
    * `remote_routes`: Map of local routes for the connection
      * `type`: Type of route
      * `static_network`: Destination prefix of the route; needs to be a valid IPv4 prefix
    * `tunnels`: The tunnels to create for this connection
      * `remote_address`: The remote address for the tunnel
      * `ipsec_properties`: Set properties of IPSec, if not set, defaults will be used
        * `child_rekey_time`: IKE child SA rekey time in seconds
        * `dpd_delay`: Delay before sending Dead Peer Detection packets if no traffic is detected, in seconds
        * `dpd_timeout`: Timeout period for DPD reply before considering the peer to be dead, in seconds
        * `ike_lifetime`: Maximum IKE SA lifetime in seconds()
        * `rekey_time`: IKE SA rekey time in seconds
        * `phase1_algorithms`: List of Phase 1: Proposal algorithms
        * `phase1_dh_group_numbers`: List of Phase 1 Diffie-Hellman group numbers
        * `phase1_integrity_algorithms`: List of Phase 1 integrity algorithms
        * `phase2_algorithms`: List of Phase 2: Security Association algorithms
        * `phase2_dh_group_numbers`: List of Phase 2 Diffie-Hellman group numbers
        * `phase2_integrity_algorithms`: List of Phase 2 integrity algorithms
* `gateway_vpn_psks`: Separate variable for providing psks for connection tunnels. Environment variable can be exported in the following format `export TF_VAR_gateway_vpn_psks='{"${gateway-name}-${connecton-name}-tunnel":{psk:"..."}}'`
* `static_routes`: Static routes to apply to the router, requires `router_enable` is set to true
* `network_peerings`: Other UpCloud private networks to peer with, requires `router_enable` is set to true
* `server_groups`: Group servers together
  * `servers`: The servers that should be included in the group.
  * `anti_affinity_policy`: Defines if a server group is an anti-affinity group. Setting this to "strict" or yes" will result in all servers in the group being placed on separate compute hosts. The value can be "strict", "yes" or "no". "strict" refers to strict policy doesn't allow servers in the same server group to be on the same host. "yes" refers to best-effort policy and tries to put servers on different hosts, but this is not guaranteed.
