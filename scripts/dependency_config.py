ARCHITECTURES = ['arm', 'arm64', 'amd64', 'ppc64le']
OSES = ['darwin', 'linux', 'windows']
README_COMPONENTS = ['etcd', 'containerd', 'crio', 'calicoctl', 'krew', 'helm']
SHA256REGEX = r'(\b[a-f0-9]{64})\b'

PATH_DOWNLOAD = 'roles/kubespray-defaults/defaults/main/download.yml'
PATH_CHECKSUM = 'roles/kubespray-defaults/defaults/main/checksums.yml'
PATH_MAIN = 'roles/kubespray-defaults/defaults/main/main.yml'
PATH_README = 'README.md'
PATH_VERSION_DIFF = 'version_diff.json'

COMPONENT_INFO = {
    'calico_crds': {
        'owner': 'projectcalico',
        'repo': 'calico',
        'url_download': 'https://github.com/projectcalico/calico/archive/{version}.tar.gz',
        'placeholder_version': ['calico_version'],
        'placeholder_checksum' : 'calico_crds_archive_checksums',
        'checksum_structure' : 'simple',
        'sha_regex' : r'', # binary
        },
    'calicoctl': {
        'owner': 'projectcalico',
        'repo': 'calico',
        'url_download': 'https://github.com/projectcalico/calico/releases/download/{version}/SHA256SUMS',
        'placeholder_version': ['calico_version'],
        'placeholder_checksum' : 'calicoctl_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'linux-{arch}\b',
        },
    'ciliumcli': {
        'owner': 'cilium',
        'repo': 'cilium-cli',
        'url_download': 'https://github.com/cilium/cilium-cli/releases/download/{version}/cilium-linux-{arch}.tar.gz.sha256sum',
        'placeholder_version': ['cilium_cli_version'],
        'placeholder_checksum' : 'ciliumcli_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'{arch}',
        },
    'cni': {
        'owner': 'containernetworking',
        'repo': 'plugins',
        'url_download': 'https://github.com/containernetworking/plugins/releases/download/{version}/cni-plugins-linux-{arch}-{version}.tgz.sha256',
        'placeholder_version': ['cni_version'],
        'placeholder_checksum' : 'cni_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'{arch}',
        },
    'containerd': {
        'owner': 'containerd',
        'repo': 'containerd',
        'url_download': 'https://github.com/containerd/containerd/releases/download/v{version}/containerd-{version}-linux-{arch}.tar.gz.sha256sum',
        'placeholder_version': ['containerd_version'],
        'placeholder_checksum' : 'containerd_archive_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'{arch}',
        },
    'crictl': {
        'owner': 'kubernetes-sigs',
        'repo': 'cri-tools',
        'url_download': 'https://github.com/kubernetes-sigs/cri-tools/releases/download/{version}/crictl-{version}-linux-{arch}.tar.gz.sha256',
        'placeholder_version': ['crictl_supported_versions', 'kube_major_version'],
        'placeholder_checksum' : 'crictl_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'simple', # only sha
        },
    'cri_dockerd': {
        'owner': 'Mirantis',
        'repo': 'cri-dockerd',
        'url_download': 'https://github.com/Mirantis/cri-dockerd/releases/download/v{version}/cri-dockerd-{version}.{arch}.tgz',
        'placeholder_version': ['cri_dockerd_version'],
        'placeholder_checksum' : 'cri_dockerd_archive_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'', # binary
        },
    'crio': {
        'owner': 'cri-o',
        'repo': 'cri-o',
        'url_download': 'https://storage.googleapis.com/cri-o/artifacts/cri-o.{arch}.{version}.tar.gz.sha256sum',
        'placeholder_version': ['crio_supported_versions', 'kube_major_version'],
        'placeholder_checksum' : 'crio_archive_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'{arch}',
        },
    'crun': {
        'owner': 'containers',
        'repo': 'crun',
        'url_download': 'https://github.com/containers/crun/releases/download/{version}/crun-{version}-linux-{arch}',
        'placeholder_version': ['crun_version'],
        'placeholder_checksum' : 'crun_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'', # binary
        },
    'etcd': {
        'owner': 'etcd-io',
        'repo': 'etcd',
        'url_download': 'https://github.com/etcd-io/etcd/releases/download/{version}/SHA256SUMS',
        'placeholder_version': ['etcd_supported_versions', 'kube_major_version'],
        'placeholder_checksum' : 'etcd_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'linux-{arch}\.',
        },
    'gvisor_containerd_shim': {
        'owner': 'google',
        'repo': 'gvisor',
        'url_download': 'https://storage.googleapis.com/gvisor/releases/release/{version}/{arch}/containerd-shim-runsc-v1',
        'placeholder_version': ['gvisor_version'],
        'placeholder_checksum' : 'gvisor_containerd_shim_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'', # binary
        },
    'gvisor_runsc': {
        'owner': 'google',
        'repo': 'gvisor',
        'url_download': 'https://storage.googleapis.com/gvisor/releases/release/{version}/{arch}/runsc',
        'placeholder_version': ['gvisor_version'],
        'placeholder_checksum' : 'gvisor_runsc_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'', # binary
        },
    'helm': {
        'owner': 'helm',
        'repo': 'helm',
        'url_download': 'https://get.helm.sh/helm-{version}-linux-{arch}.tar.gz.sha256sum',
        'placeholder_version': ['helm_version'],
        'placeholder_checksum' : 'helm_archive_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'{arch}',
        },

    'kata_containers': {
        'owner': 'kata-containers',
        'repo': 'kata-containers',
        'url_download': 'https://github.com/kata-containers/kata-containers/releases/download/{version}/kata-static-{version}-{arch}.tar.xz',
        'placeholder_version': ['kata_containers_version'],
        'placeholder_checksum' : 'kata_containers_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'', # binary
        },
    'krew': {
        'owner': 'kubernetes-sigs',
        'repo': 'krew',
        'url_download': 'https://github.com/kubernetes-sigs/krew/releases/download/{version}/krew-{os_name}_{arch}.tar.gz.sha256',
        'placeholder_version': ['krew_version'],
        'placeholder_checksum' : 'krew_archive_checksums',
        'checksum_structure' : 'os_arch',
        'sha_regex' : r'simple', # only sha
        },
    'kubeadm': {
        'owner': 'kubernetes',
        'repo': 'kubernetes',
        'url_download': 'https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubeadm.sha256',
        'placeholder_version': ['kube_version'],
        'placeholder_checksum' : 'kubeadm_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'simple', # only sha
        },
    'kubectl': {
        'owner': 'kubernetes',
        'repo': 'kubernetes',
        'url_download': 'https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubectl.sha256',
        'placeholder_version': ['kube_version'],
        'placeholder_checksum' : 'kubectl_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'simple', # only sha
        },
    'kubelet': {
        'owner': 'kubernetes',
        'repo': 'kubernetes',
        'url_download': 'https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubelet.sha256',
        'placeholder_version': ['kube_version'],
        'placeholder_checksum' : 'kubelet_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'simple', # only sha
        },
    'nerdctl': {
        'owner': 'containerd',
        'repo': 'nerdctl',
        'url_download': 'https://github.com/containerd/nerdctl/releases/download/v{version}/SHA256SUMS',
        'placeholder_version': ['nerdctl_version'],
        'placeholder_checksum' : 'nerdctl_archive_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'nerdctl-(?!full)[\w.-]+-linux-{arch}\.tar\.gz',
        },
    'runc': {
        'owner': 'opencontainers',
        'repo': 'runc',
        'url_download': 'https://github.com/opencontainers/runc/releases/download/{version}/runc.sha256sum',
        'placeholder_version': ['runc_version'],
        'placeholder_checksum' : 'runc_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'\.{arch}\b',
        },
    'skopeo': {
        'owner': 'containers',
        'repo': 'skopeo',
        'url_download': 'https://github.com/lework/skopeo-binary/releases/download/{version}/skopeo-linux-{arch}',
        'placeholder_version': ['skopeo_version'],
        'placeholder_checksum' : 'skopeo_binary_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'', # binary
        },
    'youki': {
        'owner': 'containers',
        'repo': 'youki',
        'url_download': 'https://github.com/containers/youki/releases/download/v{version}/youki-{version}-{arch}.tar.gz',
        'placeholder_version': ['youki_version'],
        'placeholder_checksum' : 'youki_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'', # binary
        },
    'yq': {
        'owner': 'mikefarah',
        'repo': 'yq',
        'url_download': 'https://github.com/mikefarah/yq/releases/download/{version}/checksums-bsd',
        'placeholder_version': ['yq_version'],
        'placeholder_checksum' : 'yq_checksums',
        'checksum_structure' : 'arch',
        'sha_regex' : r'SHA256 \([^)]+linux_{arch}\)',
        },
}
