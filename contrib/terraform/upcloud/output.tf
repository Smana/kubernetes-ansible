
output "master_ip" {
  value = module.kubernetes.master_ip
}

output "worker_ip" {
  value = module.kubernetes.worker_ip
}

output "bastion_ip" {
  value = module.kubernetes.bastion_ip
}

output "loadbalancer_domain" {
  value = module.kubernetes.loadbalancer_domain
}
