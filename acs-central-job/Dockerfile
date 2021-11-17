FROM quay.io/pittar/tekton-oc-toolbox:latest

RUN mkdir -p /scripts && \
    mkdir -p /manifests && \
    chgrp -R 0 /scripts && \
    chgrp -R 0 /manifests && \
    chmod -R g+rwX /scripts && \
    chmod -R g+rwX /manifests

WORKDIR /scripts

ADD deploy-bundle.sh .
