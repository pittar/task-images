FROM registry.access.redhat.com/ubi8/ubi:8.4

ENV OCP_TOOLS_VERSION=4.9
ENV YQ_VERSION=v4.13.5
ENV YQ_BINARY=yq_linux_amd64

# Curl already exists, but add:
#    * JQ & YQ
#    * More to come...
RUN dnf makecache && \
    dnf install -y \
    openssl wget jq \
    && dnf clean all && rm -rf /var/cache/dnf/*

WORKDIR /download

RUN curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-$OCP_TOOLS_VERSION/openshift-client-linux.tar.gz | tar -xz && \
    mv oc /usr/bin/oc && \
    mv kubectl /usr/bin/kubectl

RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}.tar.gz -O - | \
    tar xz && \
    mv ${YQ_BINARY} \
    /usr/bin/yq

WORKDIR /
