# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This file creates a standard build environment for building cross
# platform go binary for the architecture kubernetes cares about.
# 
# Ref: https://github.com/kubernetes/release/blob/master/images/build/cross/Dockerfile
#
# Using CI build: https://github.com/ydcool/image-builder
#

ARG GO_VERSION
FROM golang:${GO_VERSION}
#FROM golang:1.16.6

##------------------------------------------------------------
# global ARGs & ENVs
ARG TARGETPLATFORM=amd64
ARG DEBIAN_FRONTEND=noninteractive

ENV GOARM 7
ENV KUBE_DYNAMIC_CROSSPLATFORMS \
  arm64 \
  mips64el

ENV KUBE_CROSSPLATFORMS \
  linux/arm64 \
  linux/mips64le 

##------------------------------------------------------------

# Pre-compile the standard go library when cross-compiling. This is much easier now when we have go1.5+
RUN targetArch=$(echo $TARGETPLATFORM | cut -f2 -d '/') \
    && if [ ${targetArch} = "amd64" ]; then \
    for platform in ${KUBE_CROSSPLATFORMS}; do GOOS=${platform%/*} GOARCH=${platform##*/} go install std; done \
    && go clean -cache; \
fi

# Install packages
RUN apt-get -q update \
    && apt-get install -qqy \
        apt-utils \
        file \
        jq \
        patch \
        rsync \
        unzip \
        wget \
        automake \
        libtool \
        libapparmor-dev \
        libbtrfs-dev \
        libcap-dev \
        libdevmapper-dev \
        libglib2.0-dev \
        libseccomp-dev \
    && apt-get clean \
    && rm -rf -- \
        /var/lib/apt/lists/*

# Use dynamic cgo linking for architectures other than amd64 for the server platforms
# To install crossbuild essential for other architectures add the following repository.
RUN targetArch=$(echo $TARGETPLATFORM | cut -f2 -d '/') \
  && if [ ${targetArch} = "amd64" ]; then \
    echo "deb http://archive.ubuntu.com/ubuntu xenial main universe" > /etc/apt/sources.list.d/cgocrosscompiling.list \
    && apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys 40976EAF437D05B5 3B4FE6ACC0B21F32 \
    && apt-get update \
    && apt-get install -y build-essential \
    && for platform in ${KUBE_DYNAMIC_CROSSPLATFORMS}; do apt-get install -y crossbuild-essential-${platform}; done \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* ;\
fi

RUN targetArch=$(echo $TARGETPLATFORM | cut -f2 -d '/') \
  && if [ ${targetArch} = "arm64" ] || [ ${targetArch} = "ppc64le" ]; then \
    echo "deb http://ports.ubuntu.com/ubuntu-ports/ xenial main" > /etc/apt/sources.list.d/ports.list \
    && apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys 40976EAF437D05B5 3B4FE6ACC0B21F32 \
    && apt-get update \
    && apt-get install -y build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* ;\
fi

ARG PROTOBUF_VERSION
RUN targetArch=$(echo $TARGETPLATFORM | cut -f2 -d '/') \
  && if [ ${targetArch} = "amd64" ]; then \
  ZIPNAME="protoc-${PROTOBUF_VERSION}-linux-x86_64.zip"; \
elif [ ${targetArch} = "arm64" ]; then \
  ZIPNAME="protoc-${PROTOBUF_VERSION}-linux-aarch_64.zip"; \
elif [ ${targetArch} = "ppc64le" ]; then \
  ZIPNAME="protoc-${PROTOBUF_VERSION}-linux-ppcle_64.zip"; \
fi \
  && mkdir /tmp/protoc && cd /tmp/protoc \
  && wget "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/${ZIPNAME}" \
  && unzip "${ZIPNAME}" \
  && chmod -R +rX /tmp/protoc \
  && cp -pr bin /usr/local \
  && cp -pr include /usr/local \
  && rm -rf /tmp/protoc \
  && protoc --version

# work around 64MB tmpfs size in Docker 1.6
ENV TMPDIR /tmp.k8s
RUN mkdir $TMPDIR \
  && chmod a+rwx $TMPDIR \
  && chmod o+t $TMPDIR

# Get the code coverage tool and goimports
RUN go get golang.org/x/tools/cmd/cover \
           golang.org/x/tools/cmd/goimports \
    && go clean -cache

# Download and symlink etcd. We need this for our integration tests.
ARG ETCD_VERSION
RUN targetArch=$(echo $TARGETPLATFORM | cut -f2 -d '/') \
  && mkdir -p /usr/local/src/etcd \
  && cd /usr/local/src/etcd \
  && curl -fsSL https://github.com/coreos/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-${targetArch}.tar.gz | tar -xz \
  && chown -R $(id -u):$(id -g) /usr/local/src/etcd \
  && ln -s ../src/etcd/etcd-${ETCD_VERSION}-linux-${targetArch}/etcd /usr/local/bin/

ENTRYPOINT []
