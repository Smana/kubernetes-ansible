# Use imutable image tags rather than mutable tags (like ubuntu:22.04)
FROM ubuntu:jammy-20230308
# Some tools like yamllint need this
# Pip needs this as well at the moment to install ansible
# (and potentially other packages)
# See: https://github.com/pypa/pip/issues/10219
ENV VAGRANT_VERSION=2.4.1 \
    VAGRANT_DEFAULT_PROVIDER=libvirt \
    VAGRANT_ANSIBLE_TAGS=facts \
    LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1

RUN apt update -q \
    && apt install -yq \
         libssl-dev \
         python3-dev \
         python3-pip \
         sshpass \
         apt-transport-https \
         jq \
         moreutils \
         libvirt-dev \
         openssh-client \
         rsync \
         git \
         ca-certificates \
         curl \
         gnupg2 \
         software-properties-common \
         unzip \
         libvirt-clients \
         qemu-utils \
         qemu-kvm \
         dnsmasq \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - \
    && add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    && apt update -q \
    && apt install --no-install-recommends -yq docker-ce \
    && apt autoremove -yqq --purge && apt clean && rm -rf /var/lib/apt/lists/* /var/log/*

WORKDIR /kubespray
ADD ./requirements.txt  /kubespray/requirements.txt
ADD ./tests/requirements.txt /kubespray/tests/requirements.txt
ADD ./roles/kubespray-defaults/defaults/main/main.yml /kubespray/roles/kubespray-defaults/defaults/main/main.yml


RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
    && pip install --no-compile --no-cache-dir pip -U \
    && pip install --no-compile --no-cache-dir -r tests/requirements.txt \
    && pip install --no-compile --no-cache-dir -r requirements.txt \
    && KUBE_VERSION=$(sed -n 's/^kube_version: //p' roles/kubespray-defaults/defaults/main/main.yml) \
    && curl -L https://dl.k8s.io/release/$KUBE_VERSION/bin/linux/$(dpkg --print-architecture)/kubectl -o /usr/local/bin/kubectl \
    && echo $(curl -L https://dl.k8s.io/release/$KUBE_VERSION/bin/linux/$(dpkg --print-architecture)/kubectl.sha256) /usr/local/bin/kubectl | sha256sum --check \
    && chmod a+x /usr/local/bin/kubectl \
    # Install Vagrant
    && curl -LO https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}-1_$(dpkg --print-architecture).deb \
    && dpkg -i vagrant_${VAGRANT_VERSION}-1_$(dpkg --print-architecture).deb \
    && rm vagrant_${VAGRANT_VERSION}-1_$(dpkg --print-architecture).deb \
    && vagrant plugin install vagrant-libvirt \
    # Install Kubernetes collections
    && pip install --no-compile --no-cache-dir kubernetes \
    && ansible-galaxy collection install kubernetes.core
