locals {
  # Create a list of all disks to create
  disks = flatten([
    for node_name, machine in var.machines : [
      for disk_name, disk in machine.additional_disks : {
        disk      = disk
        disk_name = disk_name
        node_name = node_name
      }
    ]
  ])

  lb_backend_servers = flatten([
    for lb_name, loadbalancer in var.loadbalancers : [
      for backend_server in loadbalancer.backend_servers : {
        port        = loadbalancer.target_port
        lb_name     = lb_name
        server_name = backend_server
      }
    ]
  ])

  gateway_connections = flatten([
    for gateway_name, gateway in var.gateways : [
      for connection_name, connection in gateway.connections : {
          "gateway_id" = upcloud_gateway.gateway[gateway_name].id
          "gateway_name" = gateway_name
          "connection_name" = connection_name
          "type" = connection.type
          "local_routes" = connection.local_routes
          "remote_routes" = connection.remote_routes
      }
    ]
  ])

  gateway_connection_tunnels = flatten([
    for gateway_name, gateway in var.gateways : [
      for connection_name, connection in gateway.connections : [
        for tunnel_name, tunnel in connection.tunnels : {
          "gateway_id" = upcloud_gateway.gateway[gateway_name].id
          "gateway_name" = gateway_name
          "connection_id" = upcloud_gateway_connection.gateway_connection["${gateway_name}-${connection_name}"].id
          "connection_name" = connection_name
          "tunnel_name" = tunnel_name
          "local_address_name" = tolist(upcloud_gateway.gateway[gateway_name].address).0.name
          "remote_address" = tunnel.remote_address
          "ipsec_properties" = tunnel.ipsec_properties
        }
      ]
    ]
  ])

  # If prefix is set, all resources will be prefixed with "${var.prefix}-"
  # Else don't prefix with anything
  resource-prefix = "%{if var.prefix != ""}${var.prefix}-%{endif}"

  master_ip = {
    for instance in upcloud_server.master :
      instance.hostname => {
        for nic in instance.network_interface :
          nic.type => nic.ip_address
        if nic.ip_address != null
      }
  }
  worker_ip = {
    for instance in upcloud_server.worker :
      instance.hostname => {
        for nic in instance.network_interface :
          nic.type => nic.ip_address
        if nic.ip_address != null
      }
  }

  bastion_ip = {
    for instance in upcloud_server.bastion :
      instance.hostname => {
        for nic in instance.network_interface :
          nic.type => nic.ip_address
        if nic.ip_address != null
      }
  }

  node_user_data = {
    for name, machine in var.machines :
      name => <<EOF
%{ if ( length(machine.dns_servers != null ? machine.dns_servers : [] ) > 0 ) || ( length(var.dns_servers) > 0 && machine.dns_servers == null ) ~}
#!/bin/bash
echo -e "[Resolve]\nDNS=${ join(" ", length(machine.dns_servers != null ? machine.dns_servers : []) > 0 ? machine.dns_servers : var.dns_servers) }" > /etc/systemd/resolved.conf

systemctl restart systemd-resolved
%{ endif ~}
EOF
  }
}

resource "upcloud_network" "private" {
  name = "${local.resource-prefix}k8s-network"
  zone = var.zone

  ip_network {
    address            = var.private_network_cidr
    dhcp_default_route = var.router_enable
    # TODO: When support for dhcp_dns for private networks are in, remove the user_data and enable it here.
    #       See more here https://github.com/UpCloudLtd/terraform-provider-upcloud/issues/562
    # dhcp_dns           = length(var.private_network_dns) > 0 ? var.private_network_dns : null
    dhcp               = true
    family             = "IPv4"
  }

  router = var.router_enable ? upcloud_router.router[0].id : null
}

resource "upcloud_storage" "additional_disks" {
  for_each = {
    for disk in local.disks : "${disk.node_name}_${disk.disk_name}" => disk.disk
  }

  size  = each.value.size
  tier  = each.value.tier
  title = "${local.resource-prefix}${each.key}"
  zone  = var.zone
}

resource "upcloud_server" "master" {
  for_each = {
    for name, machine in var.machines :
    name => machine
    if machine.node_type == "master"
  }

  hostname     = "${local.resource-prefix}${each.key}"
  plan         = each.value.plan
  cpu          = each.value.cpu
  mem          = each.value.mem
  zone         = var.zone
  server_group = each.value.server_group == null ? null : upcloud_server_group.server_groups[each.value.server_group].id

  template {
    storage = var.template_name
    size    = each.value.disk_size
  }

  dynamic "network_interface" {
    for_each = each.value.force_public_ip || var.use_public_ips ? [1] : []

    content {
      type = "public"
    }
  }

  # Private network interface
  network_interface {
    type    = "private"
    network = upcloud_network.private.id
  }

  # Ignore volumes created by csi-driver
  lifecycle {
    ignore_changes = [storage_devices]
  }

  firewall = var.firewall_enabled

  dynamic "storage_devices" {
    for_each = {
      for disk_key_name, disk in upcloud_storage.additional_disks :
      disk_key_name => disk
      # Only add the disk if it matches the node name in the start of its name
      if length(regexall("^${each.key}_.+", disk_key_name)) > 0
    }

    content {
      storage = storage_devices.value.id
    }
  }

  # Include at least one public SSH key
  login {
    user            = var.username
    keys            = var.ssh_public_keys
    create_password = false
  }

  metadata = local.node_user_data[each.key] != "" ? true : null
  user_data = local.node_user_data[each.key] != "" ? local.node_user_data[each.key] : null
}

resource "upcloud_server" "worker" {
  for_each = {
    for name, machine in var.machines :
    name => machine
    if machine.node_type == "worker"
  }

  hostname     = "${local.resource-prefix}${each.key}"
  plan         = each.value.plan
  cpu          = each.value.cpu
  mem          = each.value.mem
  zone         = var.zone
  server_group = each.value.server_group == null ? null : upcloud_server_group.server_groups[each.value.server_group].id


  template {
    storage = var.template_name
    size    = each.value.disk_size
  }

  dynamic "network_interface" {
    for_each = each.value.force_public_ip || var.use_public_ips ? [1] : []

    content {
      type = "public"
    }
  }

  # Private network interface
  network_interface {
    type    = "private"
    network = upcloud_network.private.id
  }

  # Ignore volumes created by csi-driver
  lifecycle {
    ignore_changes = [storage_devices]
  }

  firewall = var.firewall_enabled

  dynamic "storage_devices" {
    for_each = {
      for disk_key_name, disk in upcloud_storage.additional_disks :
      disk_key_name => disk
      # Only add the disk if it matches the node name in the start of its name
      if length(regexall("^${each.key}_.+", disk_key_name)) > 0
    }

    content {
      storage = storage_devices.value.id
    }
  }

  # Include at least one public SSH key
  login {
    user            = var.username
    keys            = var.ssh_public_keys
    create_password = false
  }

  metadata = local.node_user_data[each.key] != "" ? true : null
  user_data = local.node_user_data[each.key] != "" ? local.node_user_data[each.key] : null
}

resource "upcloud_server" "bastion" {
  for_each = {
    for name, machine in var.machines :
    name => machine
    if machine.node_type == "bastion"
  }

  hostname     = "${local.resource-prefix}${each.key}"
  plan         = each.value.plan
  cpu          = each.value.cpu
  mem          = each.value.mem
  zone         = var.zone
  server_group = each.value.server_group == null ? null : upcloud_server_group.server_groups[each.value.server_group].id


  template {
    storage = var.template_name
    size    = each.value.disk_size
  }

  # Private network interface
  network_interface {
    type    = "private"
    network = upcloud_network.private.id
  }

  # Private network interface
  network_interface {
    type    = "public"
  }

  firewall = var.firewall_enabled

  dynamic "storage_devices" {
    for_each = {
      for disk_key_name, disk in upcloud_storage.additional_disks :
      disk_key_name => disk
      # Only add the disk if it matches the node name in the start of its name
      if length(regexall("^${each.key}_.+", disk_key_name)) > 0
    }

    content {
      storage = storage_devices.value.id
    }
  }

  # Include at least one public SSH key
  login {
    user            = var.username
    keys            = var.ssh_public_keys
    create_password = false
  }
}

resource "upcloud_firewall_rules" "master" {
  for_each  = upcloud_server.master
  server_id = each.value.id

  dynamic "firewall_rule" {
    for_each = var.master_allowed_remote_ips

    content {
      action                 = "accept"
      comment                = "Allow master API access from this network"
      destination_port_end   = "6443"
      destination_port_start = "6443"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = firewall_rule.value.end_address
      source_address_start   = firewall_rule.value.start_address
    }
  }

  dynamic "firewall_rule" {
    for_each = length(var.master_allowed_remote_ips) > 0 ? [1] : []

    content {
      action                 = "drop"
      comment                = "Deny master API access from other networks"
      destination_port_end   = "6443"
      destination_port_start = "6443"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = "255.255.255.255"
      source_address_start   = "0.0.0.0"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.k8s_allowed_remote_ips

    content {
      action                 = "accept"
      comment                = "Allow SSH from this network"
      destination_port_end   = "22"
      destination_port_start = "22"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = firewall_rule.value.end_address
      source_address_start   = firewall_rule.value.start_address
    }
  }

  dynamic "firewall_rule" {
    for_each = length(var.k8s_allowed_remote_ips) > 0 ? [1] : []

    content {
      action                 = "drop"
      comment                = "Deny SSH from other networks"
      destination_port_end   = "22"
      destination_port_start = "22"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = "255.255.255.255"
      source_address_start   = "0.0.0.0"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.master_allowed_ports

    content {
      action                 = "accept"
      comment                = "Allow access on this port"
      destination_port_end   = firewall_rule.value.port_range_max
      destination_port_start = firewall_rule.value.port_range_min
      direction              = "in"
      family                 = "IPv4"
      protocol               = firewall_rule.value.protocol
      source_address_end     = firewall_rule.value.end_address
      source_address_start   = firewall_rule.value.start_address
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv4"
      protocol             = firewall_rule.value
      source_address_end   = "94.237.40.9"
      source_address_start = "94.237.40.9"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv4"
      protocol             = firewall_rule.value
      source_address_end   = "94.237.127.9"
      source_address_start = "94.237.127.9"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv6"
      protocol             = firewall_rule.value
      source_address_end   = "2a04:3540:53::1"
      source_address_start = "2a04:3540:53::1"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv6"
      protocol             = firewall_rule.value
      source_address_end   = "2a04:3544:53::1"
      source_address_start = "2a04:3544:53::1"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["udp"] : []

    content {
      action               = "accept"
      comment              = "NTP Port"
      source_port_end      = "123"
      source_port_start    = "123"
      direction            = "in"
      family               = "IPv4"
      protocol             = firewall_rule.value
      source_address_end   = "255.255.255.255"
      source_address_start = "0.0.0.0"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["udp"] : []

    content {
      action            = "accept"
      comment           = "NTP Port"
      source_port_end   = "123"
      source_port_start = "123"
      direction         = "in"
      family            = "IPv6"
      protocol          = firewall_rule.value
    }
  }

  firewall_rule {
    action    = var.firewall_default_deny_in ? "drop" : "accept"
    direction = "in"
  }

  firewall_rule {
    action    = var.firewall_default_deny_out ? "drop" : "accept"
    direction = "out"
  }
}

resource "upcloud_firewall_rules" "k8s" {
  for_each  = upcloud_server.worker
  server_id = each.value.id

  dynamic "firewall_rule" {
    for_each = var.k8s_allowed_remote_ips

    content {
      action                 = "accept"
      comment                = "Allow SSH from this network"
      destination_port_end   = "22"
      destination_port_start = "22"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = firewall_rule.value.end_address
      source_address_start   = firewall_rule.value.start_address
    }
  }

  dynamic "firewall_rule" {
    for_each = length(var.k8s_allowed_remote_ips) > 0 ? [1] : []

    content {
      action                 = "drop"
      comment                = "Deny SSH from other networks"
      destination_port_end   = "22"
      destination_port_start = "22"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = "255.255.255.255"
      source_address_start   = "0.0.0.0"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.worker_allowed_ports

    content {
      action                 = "accept"
      comment                = "Allow access on this port"
      destination_port_end   = firewall_rule.value.port_range_max
      destination_port_start = firewall_rule.value.port_range_min
      direction              = "in"
      family                 = "IPv4"
      protocol               = firewall_rule.value.protocol
      source_address_end     = firewall_rule.value.end_address
      source_address_start   = firewall_rule.value.start_address
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv4"
      protocol             = firewall_rule.value
      source_address_end   = "94.237.40.9"
      source_address_start = "94.237.40.9"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv4"
      protocol             = firewall_rule.value
      source_address_end   = "94.237.127.9"
      source_address_start = "94.237.127.9"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv6"
      protocol             = firewall_rule.value
      source_address_end   = "2a04:3540:53::1"
      source_address_start = "2a04:3540:53::1"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["tcp", "udp"] : []

    content {
      action               = "accept"
      comment              = "UpCloud DNS"
      source_port_end      = "53"
      source_port_start    = "53"
      direction            = "in"
      family               = "IPv6"
      protocol             = firewall_rule.value
      source_address_end   = "2a04:3544:53::1"
      source_address_start = "2a04:3544:53::1"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["udp"] : []

    content {
      action               = "accept"
      comment              = "NTP Port"
      source_port_end      = "123"
      source_port_start    = "123"
      direction            = "in"
      family               = "IPv4"
      protocol             = firewall_rule.value
      source_address_end   = "255.255.255.255"
      source_address_start = "0.0.0.0"
    }
  }

  dynamic "firewall_rule" {
    for_each = var.firewall_default_deny_in ? ["udp"] : []

    content {
      action            = "accept"
      comment           = "NTP Port"
      source_port_end   = "123"
      source_port_start = "123"
      direction         = "in"
      family            = "IPv6"
      protocol          = firewall_rule.value
    }
  }

  firewall_rule {
    action    = var.firewall_default_deny_in ? "drop" : "accept"
    direction = "in"
  }

  firewall_rule {
    action    = var.firewall_default_deny_out ? "drop" : "accept"
    direction = "out"
  }
}

resource "upcloud_firewall_rules" "bastion" {
  for_each  = upcloud_server.bastion
  server_id = each.value.id

  dynamic "firewall_rule" {
    for_each = var.bastion_allowed_remote_ips

    content {
      action                 = "accept"
      comment                = "Allow bastion SSH access from this network"
      destination_port_end   = "22"
      destination_port_start = "22"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = firewall_rule.value.end_address
      source_address_start   = firewall_rule.value.start_address
    }
  }

  dynamic "firewall_rule" {
    for_each = length(var.bastion_allowed_remote_ips) > 0 ? [1] : []

    content {
      action                 = "drop"
      comment                = "Drop bastion SSH access from other networks"
      destination_port_end   = "22"
      destination_port_start = "22"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_end     = "255.255.255.255"
      source_address_start   = "0.0.0.0"
    }
  }

  firewall_rule {
    action    = var.firewall_default_deny_in ? "drop" : "accept"
    direction = "in"
  }

  firewall_rule {
    action    = var.firewall_default_deny_out ? "drop" : "accept"
    direction = "out"
  }
}

resource "upcloud_loadbalancer" "lb" {
  count             = var.loadbalancer_enabled ? 1 : 0
  configured_status = "started"
  name              = "${local.resource-prefix}lb"
  plan              = var.loadbalancer_plan
  zone              = var.private_cloud ? var.public_zone : var.zone
  network           = var.loadbalancer_legacy_network ? upcloud_network.private.id : null

  dynamic "networks" {
    for_each = var.loadbalancer_legacy_network ? [] : [1]

    content {
      name    = "Private-Net"
      type    = "private"
      family  = "IPv4"
      network = upcloud_network.private.id
    }
  }

  dynamic "networks" {
    for_each = var.loadbalancer_legacy_network ? [] : [1]

    content {
      name   = "Public-Net"
      type   = "public"
      family = "IPv4"
    }
  }

  lifecycle {
    ignore_changes = [ maintenance_dow, maintenance_time ]
  }
}

resource "upcloud_loadbalancer_backend" "lb_backend" {
  for_each = var.loadbalancer_enabled ? var.loadbalancers : {}

  loadbalancer = upcloud_loadbalancer.lb[0].id
  name         = "lb-backend-${each.key}"
  properties {
    outbound_proxy_protocol = each.value.proxy_protocol ? "v2" : ""
  }
}

resource "upcloud_loadbalancer_frontend" "lb_frontend" {
  for_each = var.loadbalancer_enabled ? var.loadbalancers : {}

  loadbalancer         = upcloud_loadbalancer.lb[0].id
  name                 = "lb-frontend-${each.key}"
  mode                 = "tcp"
  port                 = each.value.port
  default_backend_name = upcloud_loadbalancer_backend.lb_backend[each.key].name

  dynamic "networks" {
    for_each = var.loadbalancer_legacy_network ? [] : [1]

    content {
      name   = "Public-Net"
    }
  }

  dynamic "networks" {
    for_each = each.value.allow_internal_frontend ? [1] : []

    content{
      name = "Private-Net"
    }
  }
}

resource "upcloud_loadbalancer_static_backend_member" "lb_backend_member" {
  for_each = {
    for be_server in local.lb_backend_servers :
    "${be_server.server_name}-lb-backend-${be_server.lb_name}" => be_server
    if var.loadbalancer_enabled
  }

  backend      = upcloud_loadbalancer_backend.lb_backend[each.value.lb_name].id
  name         = "${local.resource-prefix}${each.key}"
  ip           = merge(local.master_ip, local.worker_ip)["${local.resource-prefix}${each.value.server_name}"].private
  port         = each.value.port
  weight       = 100
  max_sessions = var.loadbalancer_plan == "production-small" ? 50000 : 1000
  enabled      = true
}

resource "upcloud_server_group" "server_groups" {
  for_each             = var.server_groups
  title                = each.key
  anti_affinity_policy = each.value.anti_affinity_policy
  labels               = {}
  # Managed upstream via upcloud_server resource
  members              = []
  lifecycle {
    ignore_changes = [members]
  }
}

resource "upcloud_router" "router" {
  count = var.router_enable ? 1 : 0

  name = "${local.resource-prefix}router"

  dynamic "static_route" {
    for_each = var.static_routes

    content {
      name = static_route.key

      nexthop = static_route.value["nexthop"]
      route = static_route.value["route"]
    }
  }

}

resource "upcloud_gateway" "gateway" {
  for_each = var.router_enable ? var.gateways : {}
  name = "${local.resource-prefix}${each.key}-gateway"
  zone = var.private_cloud ? var.public_zone : var.zone

  features = each.value.features
  plan = each.value.plan

  router {
    id = upcloud_router.router[0].id
  }
}

resource "upcloud_gateway_connection" "gateway_connection" {
  for_each = {
    for gc in local.gateway_connections : "${gc.gateway_name}-${gc.connection_name}" => gc
  }

  gateway = each.value.gateway_id
  name = "${local.resource-prefix}${each.key}-gateway-connection"
  type = each.value.type

  dynamic "local_route" {
    for_each = each.value.local_routes

    content {
      name           = local_route.key
      type           = local_route.value["type"]
      static_network = local_route.value["static_network"]
    }
  }

  dynamic "remote_route" {
    for_each = each.value.remote_routes

    content {
      name           = remote_route.key
      type           = remote_route.value["type"]
      static_network = remote_route.value["static_network"]
    }
  }
}

resource "upcloud_gateway_connection_tunnel" "gateway_connection_tunnel" {
  for_each = {
    for gct in local.gateway_connection_tunnels : "${gct.gateway_name}-${gct.connection_name}-${gct.tunnel_name}-tunnel" => gct
  }

  connection_id = each.value.connection_id
  name = each.key
  local_address_name = each.value.local_address_name
  remote_address = each.value.remote_address

  ipsec_auth_psk {
    psk = var.gateway_vpn_psks[each.key].psk
  }

  dynamic "ipsec_properties" {
    for_each = each.value.ipsec_properties != null ? { "ip": each.value.ipsec_properties } : {}

    content {
        child_rekey_time = ipsec_properties.value["child_rekey_time"]
        dpd_delay = ipsec_properties.value["dpd_delay"]
        dpd_timeout = ipsec_properties.value["dpd_timeout"]
        ike_lifetime = ipsec_properties.value["ike_lifetime"]
        rekey_time = ipsec_properties.value["rekey_time"]
        phase1_algorithms = ipsec_properties.value["phase1_algorithms"]
        phase1_dh_group_numbers = ipsec_properties.value["phase1_dh_group_numbers"]
        phase1_integrity_algorithms = ipsec_properties.value["phase1_integrity_algorithms"]
        phase2_algorithms = ipsec_properties.value["phase2_algorithms"]
        phase2_dh_group_numbers = ipsec_properties.value["phase2_dh_group_numbers"]
        phase2_integrity_algorithms = ipsec_properties.value["phase2_integrity_algorithms"]
    }
  }
}

resource "upcloud_network_peering" "peering" {
  for_each = var.network_peerings

  name = "${local.resource-prefix}${each.key}"

  network {
    uuid = upcloud_network.private.id
  }

  peer_network {
    uuid = each.value.remote_network
  }
}
