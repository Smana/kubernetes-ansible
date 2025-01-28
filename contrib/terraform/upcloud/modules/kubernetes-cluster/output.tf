output "master_ip" {
  value = local.master_ip
}

output "worker_ip" {
  value = local.worker_ip
}

output "bastion_ip" {
  value = local.bastion_ip
}

output "loadbalancer_domain" {
  value = var.loadbalancer_enabled ? upcloud_loadbalancer.lb[0].dns_name : null
}
