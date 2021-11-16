FROM quay.io/pittar/tekton-oc-toolbox:latest

RUN mkdir -p /scripts && \
    chgrp -R 0 /scripts && \
    chmod -R g+rwX /scripts

WORKDIR /scripts

ADD deploy-bundle.sh .
