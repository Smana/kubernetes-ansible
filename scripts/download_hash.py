#!/usr/bin/env python3

# After a new version of Kubernetes has been released,
# run this script to update roles/kubespray-defaults/defaults/main/download.yml
# with new hashes.

import sys

from itertools import count, groupby
from collections import defaultdict
import argparse
import requests
from ruamel.yaml import YAML
from packaging.version import Version

CHECKSUMS_YML = "../roles/kubespray-defaults/defaults/main/checksums.yml"

def open_checksums_yaml():
    yaml = YAML()
    yaml.explicit_start = True
    yaml.preserve_quotes = True
    yaml.width = 4096

    with open(CHECKSUMS_YML, "r") as checksums_yml:
        data = yaml.load(checksums_yml)

    return data, yaml

def version_compare(version):
    return Version(version.removeprefix("v"))

downloads = {
    "calicoctl_binary": "https://github.com/projectcalico/calico/releases/download/{version}/SHA256SUMS",
    "ciliumcli_binary": "https://github.com/cilium/cilium-cli/releases/download/{version}/cilium-{os}-{arch}.tar.gz.sha256sum",
    "cni_binary": "https://github.com/containernetworking/plugins/releases/download/{version}/cni-plugins-{os}-{arch}-{version}.tgz.sha256",
    "containerd_archive": "https://github.com/containerd/containerd/releases/download/v{version}/containerd-{version}-{os}-{arch}.tar.gz.sha256sum",
    "crictl": "https://github.com/kubernetes-sigs/cri-tools/releases/download/{version}/critest-{version}-{os}-{arch}.tar.gz.sha256",
    "crio_archive": "https://storage.googleapis.com/cri-o/artifacts/cri-o.{arch}.{version}.tar.gz.sha256sum",
    "etcd_binary": "https://github.com/etcd-io/etcd/releases/download/{version}/SHA256SUMS",
    "kubeadm": "https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubeadm.sha256",
    "kubectl": "https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubectl.sha256",
    "kubelet": "https://dl.k8s.io/release/{version}/bin/linux/{arch}/kubelet.sha256",
    "nerdctl_archive": "https://github.com/containerd/nerdctl/releases/download/v{version}/SHA256SUMS",
    "runc": "https://github.com/opencontainers/runc/releases/download/{version}/runc.sha256sum",
    "skopeo_binary": "https://github.com/lework/skopeo-binary/releases/download/{version}/skopeo-{os}-{arch}.sha256",
    "yq": "https://github.com/mikefarah/yq/releases/download/{version}/checksums-bsd", # see https://github.com/mikefarah/yq/pull/1691 for why we use this url
}

def download_hash(only_downloads: [str]) -> None:
    # Handle file with multiples hashes, with various formats.
    # the lambda is expected to produce a dictionary of hashes indexed by arch name
    download_hash_extract = {
            "calicoctl_binary": lambda hashes : {
                line.split('-')[-1] : line.split()[0]
                for line in hashes.strip().split('\n')
                if line.count('-') == 2 and line.split('-')[-2] == "linux"
                },
            "etcd_binary": lambda hashes : {
                line.split('-')[-1].removesuffix('.tar.gz') : line.split()[0]
                for line in hashes.strip().split('\n')
                if line.split('-')[-2] == "linux"
                },
             "nerdctl_archive": lambda hashes : {
                line.split()[1].removesuffix('.tar.gz').split('-')[3] : line.split()[0]
                for line in hashes.strip().split('\n')
                if [x for x in line.split(' ') if x][1].split('-')[2] == "linux"
                },
            "runc": lambda hashes : {
                parts[1].split('.')[1] : parts[0]
                for parts in (line.split()
                              for line in hashes.split('\n')[3:9])
                },
             "yq": lambda rhashes_bsd : {
                 pair[0].split('_')[-1] : pair[1]
                 # pair = (yq_<os>_<arch>, <hash>)
                 for pair in ((line.split()[1][1:-1], line.split()[3])
                     for line in rhashes_bsd.splitlines()
                     if line.startswith("SHA256"))
                 if pair[0].startswith("yq")
                     and pair[0].split('_')[1] == "linux"
                     and not pair[0].endswith(".tar.gz")
                },
            }

    data, yaml = open_checksums_yaml()

    for download, url in (downloads if only_downloads == []
                          else {k:downloads[k] for k in downloads.keys() & only_downloads}).items():
        checksum_name = f"{download}_checksums"
        # Propagate new patch versions to all architectures
        for arch in data[checksum_name].values():
            for arch2 in data[checksum_name].values():
                arch.update({
                    v:("NONE" if arch2[v] == "NONE" else 0)
                    for v in (set(arch2.keys()) - set(arch.keys()))
                    if v.split('.')[2] == '0'})
                    # this is necessary to make the script indempotent,
                    # by only adding a vX.X.0 version (=minor release) in each arch
                    # and letting the rest of the script populate the potential
                    # patch versions

        for arch, versions in data[checksum_name].items():
            for minor, patches in groupby(versions.copy().keys(), lambda v : '.'.join(v.split('.')[:-1])):
                for version in (f"{minor}.{patch}" for patch in
                                count(start=int(max(patches, key=version_compare).split('.')[-1]),
                                      step=1)):
                    # Those barbaric generators do the following:
                    # Group all patches versions by minor number, take the newest and start from that
                    # to find new versions
                    if version in versions and versions[version] != 0:
                        continue
                    hash_file = requests.get(downloads[download].format(
                        version = version,
                        os = "linux",
                        arch = arch
                        ),
                     allow_redirects=True)
                    if hash_file.status_code == 404:
                        print(f"Unable to find {download} hash file for version {version} (arch: {arch}) at {hash_file.url}")
                        break
                    hash_file.raise_for_status()
                    sha256sum = hash_file.content.decode()
                    if download in download_hash_extract:
                        sha256sum = download_hash_extract[download](sha256sum).get(arch)
                        if sha256sum == None:
                            break
                    sha256sum = sha256sum.split()[0]

                    if len(sha256sum) != 64:
                        raise Exception(f"Checksum has an unexpected length: {len(sha256sum)} (binary: {download}, arch: {arch}, release: {version}, checksum: '{sha256sum}')")
                    data[checksum_name][arch][version] = sha256sum
        data[checksum_name] = {arch : {r : releases[r] for r in sorted(releases.keys(),
                                                  key=version_compare,
                                                  reverse=True)}
                               for arch, releases in data[checksum_name].items()}

    with open(CHECKSUMS_YML, "w") as checksums_yml:
        yaml.dump(data, checksums_yml)
        print(f"\n\nUpdated {CHECKSUMS_YML}\n")

parser = argparse.ArgumentParser(description=f"Add new patch versions hashes in {CHECKSUMS_YML}")
parser.add_argument('binaries', nargs='*', choices=downloads.keys())

args = parser.parse_args()
download_hash(args.binaries)
