# Dedicated node groups

To reserved some nodes for particular workload (for instances, reserved GPU node for workload using them), you should
define an Ansible group for theses nodes (statically or dynamically) and set taints and labels for these those in your inventory,
using [Ansible group variable](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html#assigning-a-variable-to-many-machines-group-variables).

See below for concrete examples.

## Nvidia GPU

When using the Nvidia GPU support in kubespray, the nodes should have the following variables set:

```yaml
node_taints:
- key: nvidia.com/gpu
  effect: NoSchedule
  ... (any other node taints)
```

TODO: add the same for labels once
