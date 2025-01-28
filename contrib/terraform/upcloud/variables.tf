variable "prefix" {
  type    = string
  default = "kubespray"

  description = "Prefix that is used to distinguish these resources from others"
}

variable "zone" {
  description = "The zone where to run the cluster"
}

variable "private_cloud" {
  description = "Whether the environment is in the private cloud region"
  default     = false
}

variable "public_zone" {
  description = "The public zone equivalent if the cluster is running in a private cloud zone"
}

variable "template_name" {
  description = "Block describing the preconfigured operating system"
}

variable "username" {
  description = "The username to use for the nodes"
  default     = "ubuntu"
}

variable "private_network_cidr" {
  description = "CIDR to use for the private network"
  default     = "172.16.0.0/24"
}

variable "dns_servers" {
  description = "DNS servers that will be used by the nodes. Until [this is solved](https://github.com/UpCloudLtd/terraform-provider-upcloud/issues/562) this is done using user_data to reconfigure resolved"

  type    = set(string)
  default = []
}

variable "use_public_ips" {
  description = "If all nodes should get a public IP"
  type        = bool
  default     = true
}

variable "machines" {
  description = "Cluster machines"

  type = map(object({
    node_type = string
    plan      = string
    cpu       = optional(number)
    mem       = optional(number)
    disk_size = number
    server_group : string
    force_public_ip : optional(bool, false)
    dns_servers : optional(set(string))
    additional_disks = map(object({
      size = number
      tier = string
    }))
  }))
}

variable "ssh_public_keys" {
  description = "List of public SSH keys which are injected into the VMs."
  type        = list(string)
}

variable "inventory_file" {
  description = "Where to store the generated inventory file"
}

variable "UPCLOUD_USERNAME" {
  description = "UpCloud username with API access"
}

variable "UPCLOUD_PASSWORD" {
  description = "Password for UpCloud API user"
}

variable "firewall_enabled" {
  description = "Enable firewall rules"
  default     = false
}

variable "master_allowed_remote_ips" {
  description = "List of IP start/end addresses allowed to access API of masters"
  type = list(object({
    start_address = string
    end_address   = string
  }))
  default = []
}

variable "k8s_allowed_remote_ips" {
  description = "List of IP start/end addresses allowed to SSH to hosts"
  type = list(object({
    start_address = string
    end_address   = string
  }))
  default = []
}

variable "bastion_allowed_remote_ips" {
  description = "List of IP start/end addresses allowed to SSH to bastion"
  type = list(object({
    start_address = string
    end_address   = string
  }))
  default = []
}

variable "master_allowed_ports" {
  description = "List of ports to allow on masters"
  type = list(object({
    protocol       = string
    port_range_min = number
    port_range_max = number
    start_address  = string
    end_address    = string
  }))
}

variable "worker_allowed_ports" {
  description = "List of ports to allow on workers"
  type = list(object({
    protocol       = string
    port_range_min = number
    port_range_max = number
    start_address  = string
    end_address    = string
  }))
}

variable "firewall_default_deny_in" {
  description = "Add firewall policies that deny all inbound traffic by default"
  default     = false
}

variable "firewall_default_deny_out" {
  description = "Add firewall policies that deny all outbound traffic by default"
  default     = false
}

variable "loadbalancer_enabled" {
  description = "Enable load balancer"
  default     = false
}

variable "loadbalancer_plan" {
  description = "Load balancer plan (development/production-small)"
  default     = "development"
}

variable "loadbalancer_legacy_network" {
  description = "If the loadbalancer should use the deprecated network field instead of networks blocks. You probably want to have this set to false"

  type    = bool
  default = false
}

variable "loadbalancers" {
  description = "Load balancers"

  type = map(object({
    proxy_protocol          = bool
    port                    = number
    target_port             = number
    allow_internal_frontend = optional(bool, false)
    backend_servers         = list(string)
  }))
  default = {}
}

variable "server_groups" {
  description = "Server groups"

  type = map(object({
    anti_affinity_policy = string
  }))

  default = {}
}

variable "router_enable" {
  description = "If a router should be enabled and connected to the private network or not"

  type    = bool
  default = false
}

variable "gateways" {
  description = "Gateways that should be connected to the router, requires router_enable is set to true"

  type = map(object({
    features = list(string)
    plan     = optional(string)
    connections = optional(map(object({
      type = string
      local_routes = optional(map(object({
        type           = string
        static_network = string
      })), {})
      remote_routes = optional(map(object({
        type           = string
        static_network = string
      })), {})
      tunnels = optional(map(object({
        remote_address = string
        ipsec_properties = optional(object({
          child_rekey_time            = number
          dpd_delay                   = number
          dpd_timeout                 = number
          ike_lifetime                = number
          rekey_time                  = number
          phase1_algorithms           = set(string)
          phase1_dh_group_numbers     = set(string)
          phase1_integrity_algorithms = set(string)
          phase2_algorithms           = set(string)
          phase2_dh_group_numbers     = set(string)
          phase2_integrity_algorithms = set(string)
        }))
      })), {})
    })), {})
  }))
  default = {}
}

variable "gateway_vpn_psks" {
  description = "Separate variable for providing psks for connection tunnels"

  type = map(object({
    psk = string
  }))
  default   = {}
  sensitive = true
}

variable "static_routes" {
  description = "Static routes to apply to the router, requires router_enable is set to true"

  type = map(object({
    nexthop = string
    route   = string
  }))
  default = {}
}

variable "network_peerings" {
  description = "Other UpCloud private networks to peer with, requires router_enable is set to true"

  type = map(object({
    remote_network = string
  }))
  default = {}
}
