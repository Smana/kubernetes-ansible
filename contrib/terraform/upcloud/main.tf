
terraform {
  required_version = ">= 0.13.0"
}
provider "upcloud" {
  # Your UpCloud credentials are read from  environment variables:
  username = var.UPCLOUD_USERNAME
  password = var.UPCLOUD_PASSWORD
}

module "kubernetes" {
  source = "./modules/kubernetes-cluster"

  prefix        = var.prefix
  zone          = var.zone
  private_cloud = var.private_cloud
  public_zone   = var.public_zone

  template_name = var.template_name
  username      = var.username

  private_network_cidr = var.private_network_cidr
  dns_servers          = var.dns_servers
  use_public_ips       = var.use_public_ips

  machines = var.machines

  ssh_public_keys = var.ssh_public_keys

  firewall_enabled           = var.firewall_enabled
  firewall_default_deny_in   = var.firewall_default_deny_in
  firewall_default_deny_out  = var.firewall_default_deny_out
  master_allowed_remote_ips  = var.master_allowed_remote_ips
  k8s_allowed_remote_ips     = var.k8s_allowed_remote_ips
  bastion_allowed_remote_ips = var.bastion_allowed_remote_ips
  master_allowed_ports       = var.master_allowed_ports
  worker_allowed_ports       = var.worker_allowed_ports

  loadbalancer_enabled        = var.loadbalancer_enabled
  loadbalancer_plan           = var.loadbalancer_plan
  loadbalancer_legacy_network = var.loadbalancer_legacy_network
  loadbalancers               = var.loadbalancers

  router_enable    = var.router_enable
  gateways         = var.gateways
  gateway_vpn_psks = var.gateway_vpn_psks
  static_routes    = var.static_routes
  network_peerings = var.network_peerings

  server_groups = var.server_groups
}

#
# Generate ansible inventory
#

resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    master_ip  = module.kubernetes.master_ip
    worker_ip  = module.kubernetes.worker_ip
    bastion_ip = module.kubernetes.bastion_ip
    username   = var.username
  })
  filename = var.inventory_file
}
