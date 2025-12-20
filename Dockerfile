# =============================================================================
# Realtek r8127 10G NIC Driver - Talos System Extension
# Multi-Arch Build (ARM64 + AMD64)
# =============================================================================

# Talos 1.12.0-rc.1 verwendet Kernel 6.12.6
ARG KERNEL_VERSION=6.12.6

# -----------------------------------------------------------------------------
# Stage 1: Build Environment
# -----------------------------------------------------------------------------
FROM alpine:3.19 AS builder

ARG TARGETARCH
ARG KERNEL_VERSION

# Build Dependencies
RUN apk add --no-cache \
    build-base \
    linux-headers \
    elfutils-dev \
    bc \
    flex \
    bison \
    perl \
    openssl-dev \
    openssl \
    xz \
    bash \
    coreutils \
    findutils \
    gawk \
    wget \
    tar \
    gzip \
    python3 \
    diffutils \
    rsync

WORKDIR /build

# Kopiere Treiber Source
COPY r8127-11.015.00/ /build/driver/

# Download Kernel Headers
RUN echo "Downloading kernel headers for ${KERNEL_VERSION}..." && \
    MAJOR_VERSION=$(echo ${KERNEL_VERSION} | cut -d. -f1) && \
    mkdir -p /usr/src && \
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR_VERSION}.x/linux-${KERNEL_VERSION}.tar.xz" -O /tmp/linux.tar.xz && \
    tar xf /tmp/linux.tar.xz -C /usr/src && \
    mv /usr/src/linux-* /usr/src/linux && \
    rm /tmp/linux.tar.xz && \
    echo "Kernel ${KERNEL_VERSION} headers downloaded"

# Konfiguriere Kernel fuer Module Build
RUN cd /usr/src/linux && \
    echo "Configuring kernel for ${TARGETARCH}..." && \
    make defconfig && \
    make modules_prepare && \
    echo "Kernel configured"

# Build Kernel Module
RUN cd /build/driver/src && \
    echo "Building r8127 driver for kernel ${KERNEL_VERSION}..." && \
    make -C /usr/src/linux M=$(pwd) modules && \
    ls -la *.ko && \
    echo "Build successful!"

# Installiere Modul
RUN mkdir -p /rootfs/lib/modules/${KERNEL_VERSION}-talos/extras && \
    install -m 644 /build/driver/src/r8127.ko /rootfs/lib/modules/${KERNEL_VERSION}-talos/extras/r8127.ko && \
    echo "r8127" > /rootfs/lib/modules/${KERNEL_VERSION}-talos/extras/r8127.conf && \
    echo "Installed r8127.ko for kernel ${KERNEL_VERSION}-talos"

# -----------------------------------------------------------------------------
# Stage 2: Extension Image (Scratch)
# -----------------------------------------------------------------------------
FROM scratch AS extension

# Extension Files
COPY --from=builder /rootfs/lib /lib

# Metadata
LABEL org.opencontainers.image.title="r8127"
LABEL org.opencontainers.image.description="Realtek RTL8127 10 Gigabit Ethernet driver for Talos Linux"
LABEL org.opencontainers.image.version="11.015.00"
LABEL org.opencontainers.image.authors="Realtek / Vanessa Kramer"
LABEL io.talos.extension.name="r8127"
LABEL io.talos.extension.version="v11.015.00"
