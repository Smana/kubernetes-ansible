# Ansible

## Installing Ansible

Kubespray supports multiple ansible versions and ships different `requirements.txt` files for them.
Depending on your available python version you may be limited in choosing which ansible version to use.

It is recommended to deploy the ansible version used by kubespray into a python virtual environment.

Download kubespray git directory and run below commands at the parent directory of`kubespray`:

```ShellSession
VENVDIR=kubespray-venv
KUBESPRAYDIR=kubespray
python3 -m venv $VENVDIR
source $VENVDIR/bin/activate
cd $KUBESPRAYDIR
pip install -U -r requirements.txt
```

In case you have a similar message when installing the requirements:

```ShellSession
ERROR: Could not find a version that satisfies the requirement ansible==7.6.0 (from -r requirements.txt (line 1)) (from versions: [...], 6.7.0)
ERROR: No matching distribution found for ansible==7.6.0 (from -r requirements.txt (line 1))
```

It means that the version of Python you are running is not compatible with the version of Ansible that Kubespray supports.
If the latest version supported according to pip is 6.7.0 it means you are running Python 3.8 or lower while you need at least Python 3.9 (see the table below).

### Ansible Python Compatibility

Based on the table below and the available python version for your ansible host you should choose the appropriate ansible version to use with kubespray.

| Ansible Version | Python Version |
|-----------------|----------------|
| >= 2.16.4       | 3.10-3.12      |

## Customize Ansible vars

Kubespray expects users to use one of the following variables sources for settings and customization:

| Layer                                  | Comment                                                                      |
|----------------------------------------|------------------------------------------------------------------------------|
| inventory vars                         |                                                                              |
|  - **inventory group_vars**            | most used                                                                    |
|  - inventory host_vars                 | host specifc vars overrides, group_vars is usually more practical            |
| **extra vars** (always win precedence) | override with ``ansible-playbook -e @foo.yml``                               |

[!IMPORTANT]
Extra vars are best used to override kubespray internal variables, for instances, roles/vars/.
Those vars are usually **not expected** (by Kubespray developers) to be modified by end users, and not part of Kubespray
interface. Thus they can change, disappear, or break stuff unexpectedly.

## Ansible tags

The following tags are defined in playbooks:

| Tag name                       | Used for                                              |
|--------------------------------|-------------------------------------------------------|
| annotate                       | Create kube-router annotation                         |
| apps                           | K8s apps definitions                                  |
| asserts                        | Check tasks for download role                         |
| aws-ebs-csi-driver             | Configuring csi driver: aws-ebs                       |
| azure-csi-driver               | Configuring csi driver: azure                         |
| bastion                        | Setup ssh config for bastion                          |
| bootstrap-os                   | Anything related to host OS configuration             |
| calico                         | Network plugin Calico                                 |
| calico_rr                      | Configuring Calico route reflector                    |
| cephfs-provisioner             | Configuring CephFS                                    |
| cert-manager                   | Configuring certificate manager for K8s               |
| cilium                         | Network plugin Cilium                                 |
| cinder-csi-driver              | Configuring csi driver: cinder                        |
| client                         | Kubernetes clients role                               |
| cloud-provider                 | Cloud-provider related tasks                          |
| cluster-roles                  | Configuring cluster wide application (psp ...)        |
| cni                            | CNI plugins for Network Plugins                       |
| containerd                     | Configuring containerd engine runtime for hosts       |
| container_engine_accelerator   | Enable nvidia accelerator for runtimes                |
| container-engine               | Configuring container engines                         |
| container-runtimes             | Configuring container runtimes                        |
| control-plane                  | Configuring K8s control plane node role               |
| coredns                        | Configuring coredns deployment                        |
| crio                           | Configuring crio container engine for hosts           |
| crun                           | Configuring crun runtime                              |
| csi-driver                     | Configuring csi driver                                |
| dashboard                      | Installing and configuring the Kubernetes Dashboard   |
| dns                            | Remove dns entries when resetting                     |
| docker                         | Configuring docker engine runtime for hosts           |
| download                       | Fetching container images to a delegate host          |
| etcd                           | Configuring etcd cluster                              |
| etcd-secrets                   | Configuring etcd certs/keys                           |
| etchosts                       | Configuring /etc/hosts entries for hosts              |
| external-cloud-controller      | Configure cloud controllers                           |
| external-openstack             | Cloud controller : openstack                          |
| external-provisioner           | Configure external provisioners                       |
| external-vsphere               | Cloud controller : vsphere                            |
| facts                          | Gathering facts and misc check results                |
| files                          | Remove files when resetting                           |
| flannel                        | Network plugin flannel                                |
| gce                            | Cloud-provider GCP                                    |
| gcp-pd-csi-driver              | Configuring csi driver: gcp-pd                        |
| gvisor                         | Configuring gvisor runtime                            |
| helm                           | Installing and configuring Helm                       |
| ingress-controller             | Configure ingress controllers                         |
| ingress_alb                    | AWS ALB Ingress Controller                            |
| init                           | Windows kubernetes init nodes                         |
| iptables                       | Flush and clear iptable when resetting                |
| k8s-pre-upgrade                | Upgrading K8s cluster                                 |
| kata-containers                | Configuring kata-containers runtime                   |
| kubeadm                        | Roles linked to kubeadm tasks                         |
| kube-apiserver                 | Configuring static pod kube-apiserver                 |
| kube-controller-manager        | Configuring static pod kube-controller-manager        |
| kube-vip                       | Installing and configuring kube-vip                   |
| kubectl                        | Installing kubectl and bash completion                |
| kubelet                        | Configuring kubelet service                           |
| kube-ovn                       | Network plugin kube-ovn                               |
| kube-router                    | Network plugin kube-router                            |
| kube-proxy                     | Configuring static pod kube-proxy                     |
| localhost                      | Special steps for the localhost (ansible runner)      |
| local-path-provisioner         | Configure External provisioner: local-path            |
| local-volume-provisioner       | Configure External provisioner: local-volume          |
| macvlan                        | Network plugin macvlan                                |
| master (DEPRECATED)            | Deprecated - see `control-plane`                      |
| metallb                        | Installing and configuring metallb                    |
| metrics_server                 | Configuring metrics_server                            |
| netchecker                     | Installing netchecker K8s app                         |
| network                        | Configuring networking plugins for K8s                |
| mounts                         | Umount kubelet dirs when reseting                     |
| multus                         | Network plugin multus                                 |
| nginx                          | Configuring LB for kube-apiserver instances           |
| node                           | Configuring K8s minion (compute) node role            |
| nodelocaldns                   | Configuring nodelocaldns daemonset                    |
| node-label                     | Tasks linked to labeling of nodes                     |
| node-webhook                   | Tasks linked to webhook (granting access to resources)|
| nvidia_gpu                     | Enable nvidia accelerator for runtimes                |
| oci                            | Cloud provider: oci                                   |
| persistent_volumes             | Configure csi volumes                                 |
| persistent_volumes_aws_ebs_csi | Configuring csi driver: aws-ebs                       |
| persistent_volumes_cinder_csi  | Configuring csi driver: cinder                        |
| persistent_volumes_gcp_pd_csi  | Configuring csi driver: gcp-pd                        |
| persistent_volumes_openstack   | Configuring csi driver: openstack                     |
| policy-controller              | Configuring Calico policy controller                  |
| post-remove                    | Tasks running post-remove operation                   |
| post-upgrade                   | Tasks running post-upgrade operation                  |
| pre-remove                     | Tasks running pre-remove operation                    |
| pre-upgrade                    | Tasks running pre-upgrade operation                   |
| preinstall                     | Preliminary configuration steps                       |
| registry                       | Configuring local docker registry                     |
| reset                          | Tasks running doing the node reset                    |
| resolvconf                     | Configuring /etc/resolv.conf for hosts/apps           |
| rbd-provisioner                | Configure External provisioner: rdb                   |
| services                       | Remove services (etcd, kubelet etc...) when resetting |
| snapshot                       | Enabling csi snapshot                                 |
| snapshot-controller            | Configuring csi snapshot controller                   |
| system-packages                | Install packages using OS package manager             |
| upgrade                        | Upgrading, f.e. container images/binaries             |
| upload                         | Distributing images/binaries across hosts             |
| vsphere-csi-driver             | Configuring csi driver: vsphere                       |
| weave                          | Network plugin Weave                                  |
| win_nodes                      | Running windows specific tasks                        |
| youki                          | Configuring youki runtime                             |

Note: Use the ``bash scripts/gen_tags.sh`` command to generate a list of all
tags found in the codebase. New tags will be listed with the empty "Used for"
field.

## Example commands

Example command to filter and apply only DNS configuration tasks and skip
everything else related to host OS configuration and downloading images of containers:

```ShellSession
ansible-playbook -i inventory/sample/hosts.ini cluster.yml --tags preinstall,facts --skip-tags=download,bootstrap-os
```

And this play only removes the K8s cluster DNS resolver IP from hosts' /etc/resolv.conf files:

```ShellSession
ansible-playbook -i inventory/sample/hosts.ini -e dns_mode='none' cluster.yml --tags resolvconf
```

And this prepares all container images locally (at the ansible runner node) without installing
or upgrading related stuff or trying to upload container to K8s cluster nodes:

```ShellSession
ansible-playbook -i inventory/sample/hosts.ini cluster.yml \
    -e download_run_once=true -e download_localhost=true \
    --tags download --skip-tags upload,upgrade
```

Note: use `--tags` and `--skip-tags` wisely and only if you're 100% sure what you're doing.

## Mitogen

Mitogen support is deprecated, please see [mitogen related docs](/docs/advanced/mitogen.md) for usage and reasons for deprecation.

## Troubleshooting Ansible issues

Having the wrong version of ansible, ansible collections or python dependencies can cause issue.
In particular, Kubespray ship custom modules which Ansible needs to find, for which you should specify [ANSIBLE_LIBRAY](https://docs.ansible.com/ansible/latest/dev_guide/developing_locally.html#adding-a-module-or-plugin-outside-of-a-collection)

```ShellSession
export ANSIBLE_LIBRAY=<kubespray_dir>/library`
```

A simple way to ensure you get all the correct version of Ansible is to use
the [pre-built docker image from Quay](https://quay.io/repository/kubespray/kubespray?tab=tags).
You will then need to use [bind mounts](https://docs.docker.com/storage/bind-mounts/)
to access the inventory and SSH key in the container, like this:

```ShellSession
git checkout v2.27.0
docker pull quay.io/kubespray/kubespray:v2.27.0
docker run --rm -it --mount type=bind,source="$(pwd)"/inventory/sample,dst=/inventory \
  --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa \
  quay.io/kubespray/kubespray:v2.27.0 bash
# Inside the container you may now run the kubespray playbooks:
ansible-playbook -i /inventory/inventory.ini --private-key /root/.ssh/id_rsa cluster.yml
```
