[all]
${connection_strings_master}
${connection_strings_node}
${connection_strings_etcd}
${public_ip_address_bastion}

[bastion]
${public_ip_address_bastion} ansible_user=${ansible_user}

[kube-master]
${list_master}


[kube-node]
${list_node}


[etcd]
${list_etcd}


[k8s-cluster:children]
kube-node
kube-master


[k8s-cluster:vars]
${elb_api_fqdn}
