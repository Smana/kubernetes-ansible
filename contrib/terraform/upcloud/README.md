# Kubernetes on UpCloud with Terraform

Provision a Kubernetes cluster on [UpCloud](https://upcloud.com/) using Terraform and Kubespray

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
* `dns_servers`: DNS servers that will be used by the nodes. Until [this is solved](https://github.com/UpCloudLtd/terraform-provider-upcloud/issues/562) this is done using user_data to reconfigure resolved. Defaults to `[]`
* `use_public_ips`: If a NIC connencted to the Public network should be attached to all nodes by default. Can be overridden by `force_public_ip` if this is set to `false`. Defaults to `true`
* `ssh_public_keys`: List of public SSH keys to install on all machines
* `zone`: The zone where to run the cluster
* `machines`: Machines to provision. Key of this object will be used as the name of the machine
  * `node_type`: The role of this node *(master|worker)*
  * `plan`: Preconfigured cpu/mem plan to use (disables `cpu` and `mem` attributes below)
  * `cpu`: number of cpu cores
  * `mem`: memory size in MB
  * `disk_size`: The size of the storage in GB
  * `force_public_ip`: If `use_public_ips` is set to `false`, this forces a public NIC onto the machine anyway when set to `true`. Useful if you're migrating from public nodes to only private. Defaults to `false`
  * `dns_servers`: This works the same way as the global `dns_severs` but only applies to a single node. If set to `[]` while the global `dns_servers` is set to something else, then it will not add the user_data and thus will not be recreated. Useful if you're migrating from public nodes to only private. Defaults to `null`
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
  * `proxy_protocol`: If the loadbalancer should set up the backend using proxy protocol.
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

## Migration

When `null_resource.inventories` and `data.template_file.inventory` was changed to `local_file.inventory` the old state file needs to be cleaned of the old state.
The error messages you'll see if you encounter this is:

```text
Error: failed to read schema for null_resource.inventories in registry.terraform.io/hashicorp/null: failed to instantiate provider "registry.terraform.io/hashicorp/null" to obtain schema: unavailable provider "registry.terraform.io/hashicorp/null"
Error: failed to read schema for data.template_file.inventory in registry.terraform.io/hashicorp/template: failed to instantiate provider "registry.terraform.io/hashicorp/template" to obtain schema: unavailable provider "registry.terraform.io/hashicorp/template"
```

This can be fixed with the following lines

```bash
terraform state rm -state=terraform.tfstate null_resource.inventories
terraform state rm -state=terraform.tfstate data.template_file.inventory
```

### Public to Private only migration

Since there's no way to remove the public NIC on a machine without recreating its private NIC it's not possible to inplace change a cluster to only use private IPs.
The way to migrate is to first set `use_public_ips` to `false`, `dns_servers` to some DNS servers and then update all existing servers to have `force_public_ip` set to `true` and `dns_severs` set to `[]`.
After that you can add new nodes without `force_public_ip` and `dns_servers` set and create them.
Add the new nodes into the cluster and when all of them are added, remove the old nodes.
