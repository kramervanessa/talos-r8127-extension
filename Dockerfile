# =============================================================================
# Realtek r8127 10G NIC Driver - Talos System Extension
# Multi-Arch Build (ARM64 + AMD64)
# =============================================================================

# Talos 1.12.0-rc.1 verwendet Kernel 6.18.0-talos
ARG KERNEL_VERSION=6.18

# -----------------------------------------------------------------------------
# Stage 1: Build Environment
# -----------------------------------------------------------------------------
FROM alpine:3.20 AS builder

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
    rsync \
    pahole \
    kmod \
    zstd

WORKDIR /build

# Kopiere Treiber Source
COPY r8127-11.015.00/ /build/driver/

# Download Kernel 6.18 Source
RUN echo "Downloading kernel ${KERNEL_VERSION}..." && \
    mkdir -p /usr/src && \
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz" -O /tmp/linux.tar.xz && \
    tar xf /tmp/linux.tar.xz -C /usr/src && \
    mv /usr/src/linux-* /usr/src/linux && \
    rm /tmp/linux.tar.xz && \
    echo "Kernel ${KERNEL_VERSION} downloaded"

# Konfiguriere Kernel fuer Module Build
RUN cd /usr/src/linux && \
    echo "Configuring kernel for ${TARGETARCH}..." && \
    make defconfig && \
    scripts/config --disable CONFIG_MODVERSIONS && \
    scripts/config --enable CONFIG_MODULES && \
    scripts/config --enable CONFIG_MODULE_UNLOAD && \
    # Setze EXTRAVERSION passend zur Talos Version (6.18.0-talos)
    sed -i 's/^EXTRAVERSION =.*/EXTRAVERSION = .0-talos/' Makefile && \
    make olddefconfig && \
    make modules_prepare && \
    touch Module.symvers && \
    # Zeige resultierende Kernel Version
    cat include/config/kernel.release && \
    echo "Kernel configured"

# Build Kernel Module
RUN cd /build/driver/src && \
    echo "Building r8127 driver..." && \
    KBUILD_MODPOST_WARN=1 make -C /usr/src/linux M=$(pwd) modules && \
    ls -la *.ko && \
    echo "Build successful!"

# Erstelle Talos Extension Struktur mit korrekter Kernel Version (6.18.0-talos)
RUN KVER="6.18.0-talos" && \
    mkdir -p /rootfs/rootfs/lib/modules/${KVER}/extras && \
    install -m 644 /build/driver/src/r8127.ko /rootfs/rootfs/lib/modules/${KVER}/extras/r8127.ko && \
    # Generiere modules.dep
    depmod -b /rootfs/rootfs ${KVER} 2>/dev/null || true && \
    echo "Installed r8127.ko for kernel ${KVER}"

# Erstelle manifest.yaml fuer Talos Extension
RUN cat > /rootfs/manifest.yaml << 'EOF'
version: v1alpha1
metadata:
  name: r8127
  version: 11.015.00
  author: Realtek / Vanessa Kramer
  description: |
    Realtek RTL8127 10 Gigabit Ethernet driver for Talos Linux.
    Supports RTL8127 PCIe 10G NICs found in Minisforum MS-R1 and similar devices.
  compatibility:
    talos:
      version: ">= v1.12.0"
EOF

# -----------------------------------------------------------------------------
# Stage 2: Extension Image (Scratch) - Talos Extension Format
# -----------------------------------------------------------------------------
FROM scratch AS extension

# Kopiere Extension Struktur (manifest.yaml + rootfs/)
COPY --from=builder /rootfs/ /

# Metadata Labels
LABEL org.opencontainers.image.title="r8127"
LABEL org.opencontainers.image.description="Realtek RTL8127 10 Gigabit Ethernet driver for Talos Linux"
LABEL org.opencontainers.image.version="11.015.00"
LABEL org.opencontainers.image.authors="Realtek / Vanessa Kramer"
LABEL io.talos.extension.name="r8127"
LABEL io.talos.extension.version="v11.015.00"
