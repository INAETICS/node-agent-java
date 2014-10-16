# Dockerfile for inaetics/node-agent-service
FROM ubuntu:14.04
MAINTAINER Bram de Kruijff <bdekruijff@gmail.com> (@bdekruijff)

##APT_PROXY - allow builder to inject a proxy dynamically

# Generic update & tooling
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
  && apt-get upgrade -yq \
  && apt-get install -yq --no-install-recommends \
    curl \
    openjdk-7-jre \
  && apt-get clean

# Install etcdctl
RUN cd /tmp \
  && curl -k -L https://github.com/coreos/etcd/releases/download/v0.4.6/etcd-v0.4.6-linux-amd64.tar.gz | tar xzf - \
  && cp etcd-v0.4.6-linux-amd64/etcdctl /bin/

# Node agent resources
ADD resources /tmp
