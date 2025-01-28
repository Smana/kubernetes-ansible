# Fedora CoreOS

Tested with stable version 40.20241019.3.0

Because package installation with `rpm-ostree` requires a reboot, playbook may fail while bootstrap.
Restart playbook again.

## Containers

Tested with

- containerd
- crio

## Network

### calico

To use calico create sysctl file with ignition:

```yaml
files:
    - path: /etc/sysctl.d/reverse-path-filter.conf
      contents:
        inline: |
          net.ipv4.conf.all.rp_filter=1
```

## libvirt setup

### Prepare

Create ignition file

```json
{
  "ignition": {
     "version": "3.0.0"
  },

  "passwd": {
    "users": [
      {
        "name": "ansibleUser",
        "sshAuthorizedKeys": [
          "ssh-rsa ..publickey.."
        ],
        "groups": [ "wheel" ]
      }
    ]
  }
}
```
and [produce an Ignition Config](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/)

### create guest

see [Provisioning Fedora CoreOS on libvirt](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-libvirt/)
