# containerd

[containerd] An industry-standard container runtime with an emphasis on simplicity, robustness and portability
Kubespray supports basic functionality for using containerd as the default container runtime in a cluster.

_To use the containerd container runtime set the following variables:_

## k8s_cluster.yml

When kube_node contains etcd, you define your etcd cluster to be as well schedulable for Kubernetes workloads. Thus containerd and dockerd can not run at same time, must be set to bellow for running etcd cluster with only containerd.

```yaml
container_manager: containerd
```

## etcd.yml

```yaml
etcd_deployment_type: host
```

## Containerd config

Example: define registry mirror for docker hub

```yaml
containerd_registries_mirrors:
  - prefix: docker.io
    mirrors:
      - host: https://mirror.gcr.io
        capabilities: ["pull", "resolve"]
        skip_verify: false
      - host: https://registry-1.docker.io
        capabilities: ["pull", "resolve"]
        skip_verify: false
```

containerd falls back to `https://{{ prefix }}` when none of the mirrors have the image.
This can be changed with the [`server` field](https://github.com/containerd/containerd/blob/main/docs/hosts.md#server-field):

```yaml
containerd_registries_mirrors:
  - prefix: docker.io
    mirrors:
      - host: https://mirror.gcr.io
        capabilities: ["pull", "resolve"]
        skip_verify: false
      - host: https://registry-1.docker.io
        capabilities: ["pull", "resolve"]
        skip_verify: false
    server: https://mirror.example.org
```

The `containerd_registries` and `containerd_insecure_registries` configs are deprecated.

### Containerd Runtimes

Containerd supports multiple runtime configurations that can be used with
[RuntimeClass] Kubernetes feature. See [runtime classes in containerd] for the
details of containerd configuration.

In kubespray, the default runtime name is "runc", and it can be configured with the `containerd_runc_runtime` dictionary:

```yaml
containerd_runc_runtime:
  name: runc
  type: "io.containerd.runc.v2"
  engine: ""
  root: ""
  options:
    systemdCgroup: "false"
    binaryName: /usr/local/bin/my-runc
  base_runtime_spec: cri-base.json
```

Further runtimes can be configured with `containerd_additional_runtimes`, which
is a list of such dictionaries.

Default runtime can be changed by setting `containerd_default_runtime`.

#### Base runtime specs and limiting number of open files

`base_runtime_spec` key in a runtime dictionary is used to explicitly
specify a runtime spec json file. `runc` runtime has it set to `cri-base.json`,
which is generated with `ctr oci spec > /etc/containerd/cri-base.json` and
updated to include a custom setting for maximum number of file descriptors per
container.

You can change maximum number of file descriptors per container for the default
`runc` runtime by setting the `containerd_base_runtime_spec_rlimit_nofile`
variable.

You can tune many more [settings][runtime-spec] by supplying your own file name and content with `containerd_base_runtime_specs`:

```yaml
containerd_base_runtime_specs:
  cri-spec-custom.json: |
    {
      "ociVersion": "1.1.0",
      "process": {
        "user": {
          "uid": 0,
    ...
```

The files in this dict will be placed in containerd config directory,
`/etc/containerd` by default. The files can then be referenced by filename in a
runtime:

```yaml
containerd_runc_runtime:
  name: runc
  base_runtime_spec: cri-spec-custom.json
  ...
```

Config insecure-registry access to self hosted registries.

```yaml
containerd_registries_mirrors:
  - prefix: test.registry.io
    mirrors:
      - host: http://test.registry.io
        capabilities: ["pull", "resolve"]
        skip_verify: true
  - prefix: 172.19.16.11:5000
    mirrors:
      - host: http://172.19.16.11:5000
        capabilities: ["pull", "resolve"]
        skip_verify: true
  - prefix: repo:5000
    mirrors:
      - host: http://repo:5000
        capabilities: ["pull", "resolve"]
        skip_verify: true
```

[containerd]: https://containerd.io/
[RuntimeClass]: https://kubernetes.io/docs/concepts/containers/runtime-class/
[runtime classes in containerd]: https://github.com/containerd/containerd/blob/main/docs/cri/config.md#runtime-classes
[runtime-spec]: https://github.com/opencontainers/runtime-spec

### Optional : NRI

[Node Resource Interface](https://github.com/containerd/nri) (NRI) is disabled by default for the containerd. If you
are using contained version v1.7.0 or above, then you can enable it with the
following configuration:

```yaml
nri_enabled: true
```
