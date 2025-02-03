[all]
%{ for name, ips in master_ip ~}
${name} ansible_user=${username} ansible_host=${lookup(ips, "public", ips.private)} ip=${ips.private}
%{ endfor ~}
%{ for name, ips in worker_ip ~}
${name} ansible_user=${username} ansible_host=${lookup(ips, "public", ips.private)} ip=${ips.private}
%{ endfor ~}

[kube_control_plane]
%{ for name, ips in master_ip ~}
${name}
%{ endfor ~}

[etcd]
%{ for name, ips in master_ip ~}
${name}
%{ endfor ~}

[kube_node]
%{ for name, ips in worker_ip ~}
${name}
%{ endfor ~}

[k8s_cluster:children]
kube_control_plane
kube_node

%{ if length(bastion_ip) > 0 ~}
[bastion]
%{ for name, ips in bastion_ip ~}
bastion ansible_user=${username} ansible_host=${ips.public}
%{ endfor ~}
%{ endif ~}
