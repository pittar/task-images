FROM registry.access.redhat.com/ubi8/ubi:8.3

ENV OCP_TOOLS_VERSION=4.8

# curl and jq required for this.
RUN dnf makecache && \
    dnf install -y \
    openssl jq \
    && dnf clean all && rm -rf /var/cache/dnf/*

WORKDIR /download

RUN curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-$OCP_TOOLS_VERSION/openshift-client-linux.tar.gz | tar -xz && \
    mv oc /usr/bin/oc && \
    mv kubectl /usr/bin/kubectl

WORKDIR /

