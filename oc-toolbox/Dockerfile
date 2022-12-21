FROM registry.access.redhat.com/ubi8/ubi:8.7

ENV OCP_TOOLS_VERSION=4.11
ENV YQ_VERSION=v4.25.3
ENV YQ_BINARY=yq_linux_amd64
ENV ROXCTL_VERSION=3.73.1

RUN mkdir -p ~/.kube && \
    chgrp -R 0 ~/.kube && \
    chmod -R g+rwX ~/.kube

# Curl already exists, but add:
#    * JQ & YQ
#    * More to come...
RUN dnf makecache && \
    dnf install -y \
    openssl wget jq skopeo \
    && dnf clean all && rm -rf /var/cache/dnf/*

WORKDIR /download

# oc and kubectl
RUN curl -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-$OCP_TOOLS_VERSION/openshift-client-linux.tar.gz | tar -xz && \
    mv oc /usr/bin/oc && \
    mv kubectl /usr/bin/kubectl
    
# roxctl
RUN curl -s https://mirror.openshift.com/pub/rhacs/assets/$ROXCTL_VERSION/bin/Linux/roxctl -o roxctl && \
    mv roxctl /usr/bin/roxctl && \
    chmod a+x /usr/bin/roxctl

# yq
RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/${YQ_BINARY}.tar.gz -O - | \
    tar xz && \
    mv ${YQ_BINARY} \
    /usr/bin/yq

WORKDIR /
