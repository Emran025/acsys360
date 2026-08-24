ARG FLUTTER_VERSION=3.44.5
FROM ubuntu:24.04

ARG FLUTTER_VERSION
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt

RUN flutter config --enable-linux-desktop \
    && flutter precache --linux \
    && dart --disable-analytics \
    && flutter --disable-analytics

WORKDIR /workspace
CMD ["bash"]
