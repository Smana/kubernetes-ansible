data "openstack_images_image_v2" "vm_image" {
  count = var.image_uuid == "" ? 1 : 0
  most_recent = true
  name = var.image
}

data "openstack_images_image_v2" "gfs_image" {
  count = var.image_gfs_uuid == "" ? var.image_uuid == "" ? 1 : 0 : 0
  most_recent = true
  name = var.image_gfs == "" ? var.image : var.image_gfs
}

data "openstack_images_image_v2" "image_master" {
  count = var.image_master_uuid == "" ? var.image_uuid == "" ? 1 : 0 : 0
  name = var.image_master == "" ? var.image : var.image_master
}

data "cloudinit_config" "cloudinit" {
  part {
    content_type =  "text/cloud-config"
    content = templatefile("${path.module}/templates/cloudinit.yaml.tmpl", {
      extra_partitions = [],
      netplan_critical_dhcp_interface = ""
    })
  }
}

data "openstack_networking_network_v2" "k8s_network" {
  count = var.use_existing_network ? 1 : 0
  name  = var.network_name
}

resource "openstack_compute_keypair_v2" "k8s" {
  name       = "kubernetes-${var.cluster_name}"
  public_key = chomp(file(var.public_key_path))
}

resource "openstack_networking_secgroup_v2" "k8s_master" {
  name                 = "${var.cluster_name}-k8s-master"
  description          = "${var.cluster_name} - Kubernetes Master"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_v2" "k8s_master_extra" {
  count                = "%{if var.extra_sec_groups}1%{else}0%{endif}"
  name                 = "${var.cluster_name}-k8s-master-${var.extra_sec_groups_name}"
  description          = "${var.cluster_name} - Kubernetes Master nodes - rules not managed by terraform"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master" {
  count             = length(var.master_allowed_remote_ips)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = "6443"
  port_range_max    = "6443"
  remote_ip_prefix  = var.master_allowed_remote_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.k8s_master.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master_ports" {
  count             = length(var.master_allowed_ports)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = lookup(var.master_allowed_ports[count.index], "protocol", "tcp")
  port_range_min    = lookup(var.master_allowed_ports[count.index], "port_range_min")
  port_range_max    = lookup(var.master_allowed_ports[count.index], "port_range_max")
  remote_ip_prefix  = lookup(var.master_allowed_ports[count.index], "remote_ip_prefix", "0.0.0.0/0")
  security_group_id = openstack_networking_secgroup_v2.k8s_master.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master_ipv6_ingress" {
  count             = length(var.master_allowed_remote_ipv6_ips)
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = "6443"
  port_range_max    = "6443"
  remote_ip_prefix  = var.master_allowed_remote_ipv6_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.k8s_master.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_master_ports_ipv6_ingress" {
  count             = length(var.master_allowed_ports_ipv6)
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = lookup(var.master_allowed_ports_ipv6[count.index], "protocol", "tcp")
  port_range_min    = lookup(var.master_allowed_ports_ipv6[count.index], "port_range_min")
  port_range_max    = lookup(var.master_allowed_ports_ipv6[count.index], "port_range_max")
  remote_ip_prefix  = lookup(var.master_allowed_ports_ipv6[count.index], "remote_ip_prefix", "::/0")
  security_group_id = openstack_networking_secgroup_v2.k8s_master.id
}

resource "openstack_networking_secgroup_rule_v2" "master_egress_ipv6" {
  count             = length(var.k8s_allowed_egress_ipv6_ips)
  direction         = "egress"
  ethertype         = "IPv6"
  remote_ip_prefix  = var.k8s_allowed_egress_ipv6_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.k8s_master.id
}

resource "openstack_networking_secgroup_v2" "bastion" {
  name                 = "${var.cluster_name}-bastion"
  count                = var.number_of_bastions != "" ? 1 : 0
  description          = "${var.cluster_name} - Bastion Server"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "bastion" {
  count             = var.number_of_bastions != "" ? length(var.bastion_allowed_remote_ips) : 0
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = "22"
  port_range_max    = "22"
  remote_ip_prefix  = var.bastion_allowed_remote_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.bastion[0].id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_bastion_ports" {
  count             = length(var.bastion_allowed_ports)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = lookup(var.bastion_allowed_ports[count.index], "protocol", "tcp")
  port_range_min    = lookup(var.bastion_allowed_ports[count.index], "port_range_min")
  port_range_max    = lookup(var.bastion_allowed_ports[count.index], "port_range_max")
  remote_ip_prefix  = lookup(var.bastion_allowed_ports[count.index], "remote_ip_prefix", "0.0.0.0/0")
  security_group_id = openstack_networking_secgroup_v2.bastion[0].id
}

resource "openstack_networking_secgroup_rule_v2" "bastion_ipv6_ingress" {
  count             = var.number_of_bastions != "" ? length(var.bastion_allowed_remote_ipv6_ips) : 0
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = "22"
  port_range_max    = "22"
  remote_ip_prefix  = var.bastion_allowed_remote_ipv6_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.bastion[0].id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_bastion_ports_ipv6_ingress" {
  count             = length(var.bastion_allowed_ports_ipv6)
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = lookup(var.bastion_allowed_ports_ipv6[count.index], "protocol", "tcp")
  port_range_min    = lookup(var.bastion_allowed_ports_ipv6[count.index], "port_range_min")
  port_range_max    = lookup(var.bastion_allowed_ports_ipv6[count.index], "port_range_max")
  remote_ip_prefix  = lookup(var.bastion_allowed_ports_ipv6[count.index], "remote_ip_prefix", "::/0")
  security_group_id = openstack_networking_secgroup_v2.bastion[0].id
}

resource "openstack_networking_secgroup_v2" "k8s" {
  name                 = "${var.cluster_name}-k8s"
  description          = "${var.cluster_name} - Kubernetes"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "k8s" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
  security_group_id = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_ipv6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  remote_group_id   = openstack_networking_secgroup_v2.k8s.id
  security_group_id = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_allowed_remote_ips" {
  count             = length(var.k8s_allowed_remote_ips)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = "22"
  port_range_max    = "22"
  remote_ip_prefix  = var.k8s_allowed_remote_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "k8s_allowed_remote_ips_ipv6" {
  count             = length(var.k8s_allowed_remote_ips_ipv6)
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = "tcp"
  port_range_min    = "22"
  port_range_max    = "22"
  remote_ip_prefix  = var.k8s_allowed_remote_ips_ipv6[count.index]
  security_group_id = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "egress" {
  count             = length(var.k8s_allowed_egress_ips)
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = var.k8s_allowed_egress_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_rule_v2" "egress_ipv6" {
  count             = length(var.k8s_allowed_egress_ipv6_ips)
  direction         = "egress"
  ethertype         = "IPv6"
  remote_ip_prefix  = var.k8s_allowed_egress_ipv6_ips[count.index]
  security_group_id = openstack_networking_secgroup_v2.k8s.id
}

resource "openstack_networking_secgroup_v2" "worker" {
  name                 = "${var.cluster_name}-k8s-worker"
  description          = "${var.cluster_name} - Kubernetes worker nodes"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_v2" "worker_extra" {
  count                = "%{if var.extra_sec_groups}1%{else}0%{endif}"
  name                 = "${var.cluster_name}-k8s-worker-${var.extra_sec_groups_name}"
  description          = "${var.cluster_name} - Kubernetes worker nodes - rules not managed by terraform"
  delete_default_rules = true
}

resource "openstack_networking_secgroup_rule_v2" "worker" {
  count             = length(var.worker_allowed_ports)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = lookup(var.worker_allowed_ports[count.index], "protocol", "tcp")
  port_range_min    = lookup(var.worker_allowed_ports[count.index], "port_range_min")
  port_range_max    = lookup(var.worker_allowed_ports[count.index], "port_range_max")
  remote_ip_prefix  = lookup(var.worker_allowed_ports[count.index], "remote_ip_prefix", "0.0.0.0/0")
  security_group_id = openstack_networking_secgroup_v2.worker.id
}

resource "openstack_networking_secgroup_rule_v2" "worker_ipv6_ingress" {
  count             = length(var.worker_allowed_ports_ipv6)
  direction         = "ingress"
  ethertype         = "IPv6"
  protocol          = lookup(var.worker_allowed_ports_ipv6[count.index], "protocol", "tcp")
  port_range_min    = lookup(var.worker_allowed_ports_ipv6[count.index], "port_range_min")
  port_range_max    = lookup(var.worker_allowed_ports_ipv6[count.index], "port_range_max")
  remote_ip_prefix  = lookup(var.worker_allowed_ports_ipv6[count.index], "remote_ip_prefix", "::/0")
  security_group_id = openstack_networking_secgroup_v2.worker.id
}

resource "openstack_compute_servergroup_v2" "k8s_master" {
  count    = var.master_server_group_policy != "" ? 1 : 0
  name     = "k8s-master-srvgrp"
  policies = [var.master_server_group_policy]
}

resource "openstack_compute_servergroup_v2" "k8s_node" {
  count    = var.node_server_group_policy != "" ? 1 : 0
  name     = "k8s-node-srvgrp"
  policies = [var.node_server_group_policy]
}

resource "openstack_compute_servergroup_v2" "k8s_etcd" {
  count    = var.etcd_server_group_policy != "" ? 1 : 0
  name     = "k8s-etcd-srvgrp"
  policies = [var.etcd_server_group_policy]
}

resource "openstack_compute_servergroup_v2" "k8s_node_additional" {
  for_each = var.additional_server_groups
  name     = "k8s-${each.key}-srvgrp"
  policies = [each.value.policy]
}

locals {
# master groups
  master_sec_groups = compact([
    openstack_networking_secgroup_v2.k8s_master.id,
    openstack_networking_secgroup_v2.k8s.id,
    var.extra_sec_groups ?openstack_networking_secgroup_v2.k8s_master_extra[0].id : "",
  ])
# worker groups
  worker_sec_groups = compact([
    openstack_networking_secgroup_v2.k8s.id,
    openstack_networking_secgroup_v2.worker.id,
    var.extra_sec_groups ? openstack_networking_secgroup_v2.worker_extra[0].id : "",
  ])
# bastion groups
  bastion_sec_groups = compact(concat([
    openstack_networking_secgroup_v2.k8s.id,
    openstack_networking_secgroup_v2.bastion[0].id,
  ]))
# etcd groups
  etcd_sec_groups = compact([openstack_networking_secgroup_v2.k8s.id])
# glusterfs groups
  gfs_sec_groups = compact([openstack_networking_secgroup_v2.k8s.id])

# Image uuid
  image_to_use_node = var.image_uuid != "" ? var.image_uuid : data.openstack_images_image_v2.vm_image[0].id
# Image_gfs uuid
  image_to_use_gfs = var.image_gfs_uuid != "" ? var.image_gfs_uuid : var.image_uuid != "" ? var.image_uuid : data.openstack_images_image_v2.gfs_image[0].id
# image_master uuidimage_gfs_uuid
  image_to_use_master = var.image_master_uuid != "" ? var.image_master_uuid : var.image_uuid != "" ? var.image_uuid : data.openstack_images_image_v2.image_master[0].id

  k8s_nodes_settings = {
    for name, node in var.k8s_nodes :
      name => {
        "use_local_disk" = (node.root_volume_size_in_gb != null ? node.root_volume_size_in_gb : var.node_root_volume_size_in_gb) == 0,
        "image_id"       = node.image_id != null ? node.image_id : local.image_to_use_node,
        "volume_size"    = node.root_volume_size_in_gb != null ? node.root_volume_size_in_gb : var.node_root_volume_size_in_gb,
        "volume_type"    = node.volume_type != null ? node.volume_type : var.node_volume_type,
        "network_id"     = node.network_id != null ? node.network_id : (var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id)
        "server_group"   = node.server_group != null ? [openstack_compute_servergroup_v2.k8s_node_additional[node.server_group].id] : (var.node_server_group_policy != ""  ? [openstack_compute_servergroup_v2.k8s_node[0].id] : [])
      }
  }

  k8s_masters_settings = {
    for name, node in var.k8s_masters :
      name => {
        "use_local_disk" = (node.root_volume_size_in_gb != null ? node.root_volume_size_in_gb : var.master_root_volume_size_in_gb) == 0,
        "image_id"       = node.image_id != null ? node.image_id : local.image_to_use_master,
        "volume_size"    = node.root_volume_size_in_gb != null ? node.root_volume_size_in_gb : var.master_root_volume_size_in_gb,
        "volume_type"    = node.volume_type != null ? node.volume_type : var.master_volume_type,
        "network_id"     = node.network_id != null ? node.network_id : (var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id)
      }
  }
}

resource "openstack_networking_port_v2" "bastion_port" {
  count                 = var.number_of_bastions
  name                  = "${var.cluster_name}-bastion-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.bastion_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "bastion" {
  name       = "${var.cluster_name}-bastion-${count.index + 1}"
  count      = var.number_of_bastions
  image_id   = var.bastion_root_volume_size_in_gb == 0 ? local.image_to_use_node : null
  flavor_id  = var.flavor_bastion
  key_pair   = openstack_compute_keypair_v2.k8s.name
  user_data  = data.cloudinit_config.cloudinit.rendered

  dynamic "block_device" {
    for_each = var.bastion_root_volume_size_in_gb > 0 ? [local.image_to_use_node] : []
    content {
      uuid                  = local.image_to_use_node
      source_type           = "image"
      volume_size           = var.bastion_root_volume_size_in_gb
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.bastion_port.*.id, count.index)
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "bastion"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }

  provisioner "local-exec" {
    command = "sed -e s/USER/${var.ssh_user}/ -e s/BASTION_ADDRESS/${var.bastion_fips[0]}/ ${path.module}/ansible_bastion_template.txt > ${var.group_vars_path}/no_floating.yml"
  }
}

resource "openstack_networking_port_v2" "k8s_master_port" {
  count                 = var.number_of_k8s_masters
  name                  = "${var.cluster_name}-k8s-master-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.master_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_master" {
  name              = "${var.cluster_name}-k8s-master-${count.index + 1}"
  count             = var.number_of_k8s_masters
  availability_zone = element(var.az_list, count.index)
  image_id          = var.master_root_volume_size_in_gb == 0 ? local.image_to_use_master : null
  flavor_id         = var.flavor_k8s_master
  key_pair          = openstack_compute_keypair_v2.k8s.name
  user_data         = data.cloudinit_config.cloudinit.rendered


  dynamic "block_device" {
    for_each = var.master_root_volume_size_in_gb > 0 ? [local.image_to_use_master] : []
    content {
      uuid                  = local.image_to_use_master
      source_type           = "image"
      volume_size           = var.master_root_volume_size_in_gb
      volume_type           = var.master_volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.k8s_master_port.*.id, count.index)
  }

  dynamic "scheduler_hints" {
    for_each = var.master_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_master[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_master[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "etcd,kube_control_plane,${var.supplementary_master_groups},k8s_cluster"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }

  provisioner "local-exec" {
    command = "sed -e s/USER/${var.ssh_user}/ -e s/BASTION_ADDRESS/${element(concat(var.bastion_fips, var.k8s_master_fips), 0)}/ ${path.module}/ansible_bastion_template.txt > ${var.group_vars_path}/no_floating.yml"
  }
}

resource "openstack_networking_port_v2" "k8s_masters_port" {
  for_each              = var.number_of_k8s_masters == 0 && var.number_of_k8s_masters_no_etcd == 0 && var.number_of_k8s_masters_no_floating_ip == 0 && var.number_of_k8s_masters_no_floating_ip_no_etcd == 0 ? var.k8s_masters : {}
  name                  = "${var.cluster_name}-k8s-${each.key}"
  network_id            = local.k8s_masters_settings[each.key].network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.master_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_masters" {
  for_each          = var.number_of_k8s_masters == 0 && var.number_of_k8s_masters_no_etcd == 0 && var.number_of_k8s_masters_no_floating_ip == 0 && var.number_of_k8s_masters_no_floating_ip_no_etcd == 0 ? var.k8s_masters : {}
  name              = "${var.cluster_name}-k8s-${each.key}"
  availability_zone = each.value.az
  image_id          = local.k8s_masters_settings[each.key].use_local_disk ? local.k8s_masters_settings[each.key].image_id : null
  flavor_id         = each.value.flavor
  key_pair          = openstack_compute_keypair_v2.k8s.name

  dynamic "block_device" {
    for_each = !local.k8s_masters_settings[each.key].use_local_disk ? [local.k8s_masters_settings[each.key].image_id] : []
    content {
      uuid                  = block_device.value
      source_type           = "image"
      volume_size           = local.k8s_masters_settings[each.key].volume_size
      volume_type           = local.k8s_masters_settings[each.key].volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = openstack_networking_port_v2.k8s_masters_port[each.key].id
  }

  dynamic "scheduler_hints" {
    for_each = var.master_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_master[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_master[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "%{if each.value.etcd == true}etcd,%{endif}kube_control_plane,${var.supplementary_master_groups},k8s_cluster%{if each.value.floating_ip == false},no_floating%{endif}"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }

  provisioner "local-exec" {
    command = "%{if each.value.floating_ip}sed s/USER/${var.ssh_user}/ ${path.module}/ansible_bastion_template.txt | sed s/BASTION_ADDRESS/${element(concat(var.bastion_fips, [for key, value in var.k8s_masters_fips : value.address]), 0)}/ > ${var.group_vars_path}/no_floating.yml%{else}true%{endif}"
  }
}

resource "openstack_networking_port_v2" "k8s_master_no_etcd_port" {
  count                 = var.number_of_k8s_masters_no_etcd
  name                  = "${var.cluster_name}-k8s-master-ne-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.master_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_master_no_etcd" {
  name              = "${var.cluster_name}-k8s-master-ne-${count.index + 1}"
  count             = var.number_of_k8s_masters_no_etcd
  availability_zone = element(var.az_list, count.index)
  image_id          = var.master_root_volume_size_in_gb == 0 ? local.image_to_use_master : null
  flavor_id         = var.flavor_k8s_master
  key_pair          = openstack_compute_keypair_v2.k8s.name
  user_data         = data.cloudinit_config.cloudinit.rendered


  dynamic "block_device" {
    for_each = var.master_root_volume_size_in_gb > 0 ? [local.image_to_use_master] : []
    content {
      uuid                  = local.image_to_use_master
      source_type           = "image"
      volume_size           = var.master_root_volume_size_in_gb
      volume_type           = var.master_volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.k8s_master_no_etcd_port.*.id, count.index)
  }

  dynamic "scheduler_hints" {
    for_each = var.master_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_master[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_master[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "kube_control_plane,${var.supplementary_master_groups},k8s_cluster"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }

  provisioner "local-exec" {
    command = "sed -e s/USER/${var.ssh_user}/ -e s/BASTION_ADDRESS/${element(concat(var.bastion_fips, var.k8s_master_fips), 0)}/ ${path.module}/ansible_bastion_template.txt > ${var.group_vars_path}/no_floating.yml"
  }
}

resource "openstack_networking_port_v2" "etcd_port" {
  count                 = var.number_of_etcd
  name                  = "${var.cluster_name}-etcd-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.etcd_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "etcd" {
  name              = "${var.cluster_name}-etcd-${count.index + 1}"
  count             = var.number_of_etcd
  availability_zone = element(var.az_list, count.index)
  image_id          = var.etcd_root_volume_size_in_gb == 0 ? local.image_to_use_master : null
  flavor_id         = var.flavor_etcd
  key_pair          = openstack_compute_keypair_v2.k8s.name
  user_data         = data.cloudinit_config.cloudinit.rendered

  dynamic "block_device" {
    for_each = var.etcd_root_volume_size_in_gb > 0 ? [local.image_to_use_master] : []
    content {
      uuid                  = local.image_to_use_master
      source_type           = "image"
      volume_size           = var.etcd_root_volume_size_in_gb
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.etcd_port.*.id, count.index)
  }

  dynamic "scheduler_hints" {
    for_each = var.etcd_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_etcd[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_etcd[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "etcd,no_floating"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }
}

resource "openstack_networking_port_v2" "k8s_master_no_floating_ip_port" {
  count                 = var.number_of_k8s_masters_no_floating_ip
  name                  = "${var.cluster_name}-k8s-master-nf-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.master_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_master_no_floating_ip" {
  name              = "${var.cluster_name}-k8s-master-nf-${count.index + 1}"
  count             = var.number_of_k8s_masters_no_floating_ip
  availability_zone = element(var.az_list, count.index)
  image_id          = var.master_root_volume_size_in_gb == 0 ? local.image_to_use_master : null
  flavor_id         = var.flavor_k8s_master
  key_pair          = openstack_compute_keypair_v2.k8s.name

  dynamic "block_device" {
    for_each = var.master_root_volume_size_in_gb > 0 ? [local.image_to_use_master] : []
    content {
      uuid                  = local.image_to_use_master
      source_type           = "image"
      volume_size           = var.master_root_volume_size_in_gb
      volume_type           = var.master_volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.k8s_master_no_floating_ip_port.*.id, count.index)
  }

  dynamic "scheduler_hints" {
    for_each = var.master_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_master[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_master[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "etcd,kube_control_plane,${var.supplementary_master_groups},k8s_cluster,no_floating"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }
}

resource "openstack_networking_port_v2" "k8s_master_no_floating_ip_no_etcd_port" {
  count                 = var.number_of_k8s_masters_no_floating_ip_no_etcd
  name                  = "${var.cluster_name}-k8s-master-ne-nf-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.master_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_master_no_floating_ip_no_etcd" {
  name              = "${var.cluster_name}-k8s-master-ne-nf-${count.index + 1}"
  count             = var.number_of_k8s_masters_no_floating_ip_no_etcd
  availability_zone = element(var.az_list, count.index)
  image_id          = var.master_root_volume_size_in_gb == 0 ? local.image_to_use_master : null
  flavor_id         = var.flavor_k8s_master
  key_pair          = openstack_compute_keypair_v2.k8s.name
  user_data         = data.cloudinit_config.cloudinit.rendered

  dynamic "block_device" {
    for_each = var.master_root_volume_size_in_gb > 0 ? [local.image_to_use_master] : []
    content {
      uuid                  = local.image_to_use_master
      source_type           = "image"
      volume_size           = var.master_root_volume_size_in_gb
      volume_type           = var.master_volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.k8s_master_no_floating_ip_no_etcd_port.*.id, count.index)
  }

  dynamic "scheduler_hints" {
    for_each = var.master_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_master[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_master[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "kube_control_plane,${var.supplementary_master_groups},k8s_cluster,no_floating"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }
}

resource "openstack_networking_port_v2" "k8s_node_port" {
  count                 = var.number_of_k8s_nodes
  name                  = "${var.cluster_name}-k8s-node-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.worker_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_node" {
  name              = "${var.cluster_name}-k8s-node-${count.index + 1}"
  count             = var.number_of_k8s_nodes
  availability_zone = element(var.az_list_node, count.index)
  image_id          = var.node_root_volume_size_in_gb == 0 ? local.image_to_use_node : null
  flavor_id         = var.flavor_k8s_node
  key_pair          = openstack_compute_keypair_v2.k8s.name
  user_data         = data.cloudinit_config.cloudinit.rendered

  dynamic "block_device" {
    for_each = var.node_root_volume_size_in_gb > 0 ? [local.image_to_use_node] : []
    content {
      uuid                  = local.image_to_use_node
      source_type           = "image"
      volume_size           = var.node_root_volume_size_in_gb
      volume_type           = var.node_volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.k8s_node_port.*.id, count.index)
  }


  dynamic "scheduler_hints" {
    for_each = var.node_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_node[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_node[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "kube_node,k8s_cluster,${var.supplementary_node_groups}"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }

  provisioner "local-exec" {
    command = "sed -e s/USER/${var.ssh_user}/ -e s/BASTION_ADDRESS/${element(concat(var.bastion_fips, var.k8s_node_fips), 0)}/ ${path.module}/ansible_bastion_template.txt > ${var.group_vars_path}/no_floating.yml"
  }
}

resource "openstack_networking_port_v2" "k8s_node_no_floating_ip_port" {
  count                 = var.number_of_k8s_nodes_no_floating_ip
  name                  = "${var.cluster_name}-k8s-node-nf-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.worker_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_node_no_floating_ip" {
  name              = "${var.cluster_name}-k8s-node-nf-${count.index + 1}"
  count             = var.number_of_k8s_nodes_no_floating_ip
  availability_zone = element(var.az_list_node, count.index)
  image_id          = var.node_root_volume_size_in_gb == 0 ? local.image_to_use_node : null
  flavor_id         = var.flavor_k8s_node
  key_pair          = openstack_compute_keypair_v2.k8s.name
  user_data         = data.cloudinit_config.cloudinit.rendered

  dynamic "block_device" {
    for_each = var.node_root_volume_size_in_gb > 0 ? [local.image_to_use_node] : []
    content {
      uuid                  = local.image_to_use_node
      source_type           = "image"
      volume_size           = var.node_root_volume_size_in_gb
      volume_type           = var.node_volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.k8s_node_no_floating_ip_port.*.id, count.index)
  }

  dynamic "scheduler_hints" {
    for_each = var.node_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_node[0].id] : []
    content {
      group = scheduler_hints.value
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "kube_node,k8s_cluster,no_floating,${var.supplementary_node_groups}"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }
}

resource "openstack_networking_port_v2" "k8s_nodes_port" {
  for_each              = var.number_of_k8s_nodes == 0 && var.number_of_k8s_nodes_no_floating_ip == 0 ? var.k8s_nodes : {}
  name                  = "${var.cluster_name}-k8s-node-${each.key}"
  network_id            = local.k8s_nodes_settings[each.key].network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.worker_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  lifecycle {
    ignore_changes = [ allowed_address_pairs ]
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "k8s_nodes" {
  for_each          = var.number_of_k8s_nodes == 0 && var.number_of_k8s_nodes_no_floating_ip == 0 ? var.k8s_nodes : {}
  name              = "${var.cluster_name}-k8s-node-${each.key}"
  availability_zone = each.value.az
  image_id          = local.k8s_nodes_settings[each.key].use_local_disk ? local.k8s_nodes_settings[each.key].image_id : null
  flavor_id         = each.value.flavor
  key_pair          = openstack_compute_keypair_v2.k8s.name
  user_data         = each.value.cloudinit != null ? templatefile("${path.module}/templates/cloudinit.yaml.tmpl", {
    extra_partitions = each.value.cloudinit.extra_partitions,
    netplan_critical_dhcp_interface = each.value.cloudinit.netplan_critical_dhcp_interface,
  }) : data.cloudinit_config.cloudinit.rendered

  dynamic "block_device" {
    for_each = !local.k8s_nodes_settings[each.key].use_local_disk ? [local.k8s_nodes_settings[each.key].image_id] : []
    content {
      uuid                  = block_device.value
      source_type           = "image"
      volume_size           = local.k8s_nodes_settings[each.key].volume_size
      volume_type           = local.k8s_nodes_settings[each.key].volume_type
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = openstack_networking_port_v2.k8s_nodes_port[each.key].id
  }

  dynamic "scheduler_hints" {
    for_each = local.k8s_nodes_settings[each.key].server_group
    content {
      group = scheduler_hints.value
    }
  }

  metadata = {
    ssh_user         = var.ssh_user
    kubespray_groups = "kube_node,k8s_cluster,%{if !each.value.floating_ip}no_floating,%{endif}${var.supplementary_node_groups}${each.value.extra_groups != null ? ",${each.value.extra_groups}" : ""}"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }

  provisioner "local-exec" {
    command = "%{if each.value.floating_ip}sed -e s/USER/${var.ssh_user}/ -e s/BASTION_ADDRESS/${element(concat(var.bastion_fips, [for key, value in var.k8s_nodes_fips : value.address]), 0)}/ ${path.module}/ansible_bastion_template.txt > ${var.group_vars_path}/no_floating.yml%{else}true%{endif}"
  }
}

resource "openstack_networking_port_v2" "glusterfs_node_no_floating_ip_port" {
  count                 = var.number_of_gfs_nodes_no_floating_ip
  name                  = "${var.cluster_name}-gfs-node-nf-${count.index + 1}"
  network_id            = var.use_existing_network ? data.openstack_networking_network_v2.k8s_network[0].id : var.network_id
  admin_state_up        = "true"
  port_security_enabled = var.force_null_port_security ? null : var.port_security_enabled
  security_group_ids    = var.port_security_enabled ? local.gfs_sec_groups : null
  no_security_groups    = var.port_security_enabled ? null : false
  dynamic "fixed_ip" {
    for_each = var.private_subnet_id == "" ? [] : [true]
    content {
      subnet_id = var.private_subnet_id
    }
  }

  depends_on = [
    var.network_router_id
  ]
}

resource "openstack_compute_instance_v2" "glusterfs_node_no_floating_ip" {
  name              = "${var.cluster_name}-gfs-node-nf-${count.index + 1}"
  count             = var.number_of_gfs_nodes_no_floating_ip
  availability_zone = element(var.az_list, count.index)
  image_name        = var.gfs_root_volume_size_in_gb == 0 ? local.image_to_use_gfs : null
  flavor_id         = var.flavor_gfs_node
  key_pair          = openstack_compute_keypair_v2.k8s.name

  dynamic "block_device" {
    for_each = var.gfs_root_volume_size_in_gb > 0 ? [local.image_to_use_gfs] : []
    content {
      uuid                  = local.image_to_use_gfs
      source_type           = "image"
      volume_size           = var.gfs_root_volume_size_in_gb
      boot_index            = 0
      destination_type      = "volume"
      delete_on_termination = true
    }
  }

  network {
    port = element(openstack_networking_port_v2.glusterfs_node_no_floating_ip_port.*.id, count.index)
  }

  dynamic "scheduler_hints" {
    for_each = var.node_server_group_policy != "" ? [openstack_compute_servergroup_v2.k8s_node[0]] : []
    content {
      group = openstack_compute_servergroup_v2.k8s_node[0].id
    }
  }

  metadata = {
    ssh_user         = var.ssh_user_gfs
    kubespray_groups = "gfs-cluster,network-storage,no_floating"
    depends_on       = var.network_router_id
    use_access_ip    = var.use_access_ip
  }
}

resource "openstack_networking_floatingip_associate_v2" "bastion" {
  count                 = var.number_of_bastions
  floating_ip           = var.bastion_fips[count.index]
  port_id               = element(openstack_networking_port_v2.bastion_port.*.id, count.index)
}


resource "openstack_networking_floatingip_associate_v2" "k8s_master" {
  count                 = var.number_of_k8s_masters
  floating_ip           = var.k8s_master_fips[count.index]
  port_id               = element(openstack_networking_port_v2.k8s_master_port.*.id, count.index)
}

resource "openstack_networking_floatingip_associate_v2" "k8s_masters" {
  for_each              = var.number_of_k8s_masters == 0 && var.number_of_k8s_masters_no_etcd == 0 && var.number_of_k8s_masters_no_floating_ip == 0 && var.number_of_k8s_masters_no_floating_ip_no_etcd == 0 ? { for key, value in var.k8s_masters : key => value if value.floating_ip } : {}
  floating_ip           = var.k8s_masters_fips[each.key].address
  port_id               = openstack_networking_port_v2.k8s_masters_port[each.key].id
}

resource "openstack_networking_floatingip_associate_v2" "k8s_master_no_etcd" {
  count                 = var.master_root_volume_size_in_gb == 0 ? var.number_of_k8s_masters_no_etcd : 0
  floating_ip           = var.k8s_master_no_etcd_fips[count.index]
  port_id               = element(openstack_networking_port_v2.k8s_master_no_etcd_port.*.id, count.index)
}

resource "openstack_networking_floatingip_associate_v2" "k8s_node" {
  count                 = var.node_root_volume_size_in_gb == 0 ? var.number_of_k8s_nodes : 0
  floating_ip           = var.k8s_node_fips[count.index]
  port_id               = element(openstack_networking_port_v2.k8s_node_port.*.id, count.index)
}

resource "openstack_networking_floatingip_associate_v2" "k8s_nodes" {
  for_each              = var.number_of_k8s_nodes == 0 && var.number_of_k8s_nodes_no_floating_ip == 0 ? { for key, value in var.k8s_nodes : key => value if value.floating_ip } : {}
  floating_ip           = var.k8s_nodes_fips[each.key].address
  port_id               = openstack_networking_port_v2.k8s_nodes_port[each.key].id
}

resource "openstack_blockstorage_volume_v3" "glusterfs_volume" {
  name        = "${var.cluster_name}-glusterfs_volume-${count.index + 1}"
  count       = var.gfs_root_volume_size_in_gb == 0 ? var.number_of_gfs_nodes_no_floating_ip : 0
  description = "Non-ephemeral volume for GlusterFS"
  size        = var.gfs_volume_size_in_gb
}

resource "openstack_compute_volume_attach_v2" "glusterfs_volume" {
  count       = var.gfs_root_volume_size_in_gb == 0 ? var.number_of_gfs_nodes_no_floating_ip : 0
  instance_id = element(openstack_compute_instance_v2.glusterfs_node_no_floating_ip.*.id, count.index)
  volume_id   = element(openstack_blockstorage_volume_v3.glusterfs_volume.*.id, count.index)
}
