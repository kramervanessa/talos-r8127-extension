# =============================================================================
# Realtek r8127 10G NIC Driver - Talos System Extension
# Multi-Arch Build (ARM64 + AMD64)
# =============================================================================

ARG TALOS_VERSION=v1.12.0-rc.1

# -----------------------------------------------------------------------------
# Stage 1: Extrahiere Kernel aus Talos Installer
# -----------------------------------------------------------------------------
FROM ghcr.io/siderolabs/installer:${TALOS_VERSION} AS talos-installer

# -----------------------------------------------------------------------------
# Stage 2: Build Environment
# -----------------------------------------------------------------------------
FROM alpine:3.20 AS builder

ARG TARGETARCH

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

# Extrahiere initramfs aus Talos Installer um Kernel Version zu finden
COPY --from=talos-installer /usr/install/${TARGETARCH}/vmlinuz /tmp/vmlinuz
COPY --from=talos-installer /usr/install/${TARGETARCH}/initramfs.xz /tmp/initramfs.xz

# Extrahiere Kernel Version aus initramfs
RUN cd /tmp && \
    xz -d initramfs.xz && \
    mkdir -p /tmp/initrd && \
    cd /tmp/initrd && \
    cpio -idm < /tmp/initramfs 2>/dev/null || true && \
    KVER=$(ls lib/modules 2>/dev/null | head -1) && \
    if [ -z "$KVER" ]; then \
      echo "Trying to find kernel version from vmlinuz..." && \
      KVER=$(strings /tmp/vmlinuz | grep -oP '^\d+\.\d+\.\d+-talos$' | head -1) ; \
    fi && \
    echo "Found kernel version: ${KVER}" && \
    echo "${KVER}" > /build/kernel_version.txt

# Download passenden Kernel Source
# Talos 1.12.0-rc.1 basiert auf Linux 6.12.x (nicht 6.18!)
RUN KVER=$(cat /build/kernel_version.txt) && \
    echo "Kernel version from Talos: ${KVER}" && \
    # Extrahiere Major.Minor Version
    BASE_VER=$(echo ${KVER} | sed 's/-talos//') && \
    MAJOR=$(echo ${BASE_VER} | cut -d. -f1) && \
    MINOR=$(echo ${BASE_VER} | cut -d. -f2) && \
    PATCH=$(echo ${BASE_VER} | cut -d. -f3) && \
    echo "Downloading kernel ${MAJOR}.${MINOR}.${PATCH}..." && \
    mkdir -p /usr/src && \
    # Versuche exakte Version, dann ohne Patch
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${MAJOR}.${MINOR}.${PATCH}.tar.xz" -O /tmp/linux.tar.xz 2>/dev/null || \
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/linux-${MAJOR}.${MINOR}.tar.xz" -O /tmp/linux.tar.xz 2>/dev/null || \
    (echo "Kernel not found on kernel.org, using latest stable" && \
     wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.6.tar.xz" -O /tmp/linux.tar.xz) && \
    tar xf /tmp/linux.tar.xz -C /usr/src && \
    mv /usr/src/linux-* /usr/src/linux && \
    rm /tmp/linux.tar.xz

# Konfiguriere Kernel fuer Module Build
RUN KVER=$(cat /build/kernel_version.txt) && \
    cd /usr/src/linux && \
    echo "Configuring kernel for ${TARGETARCH}..." && \
    make defconfig && \
    scripts/config --disable CONFIG_MODVERSIONS && \
    scripts/config --enable CONFIG_MODULES && \
    scripts/config --enable CONFIG_MODULE_UNLOAD && \
    # Setze EXTRAVERSION passend zur Talos Version
    sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -talos/" Makefile && \
    make olddefconfig && \
    make modules_prepare && \
    touch Module.symvers && \
    echo "Kernel configured"

# Build Kernel Module
RUN KVER=$(cat /build/kernel_version.txt) && \
    cd /build/driver/src && \
    echo "Building r8127 driver..." && \
    KBUILD_MODPOST_WARN=1 make -C /usr/src/linux M=$(pwd) modules && \
    ls -la *.ko && \
    echo "Build successful!"

# Erstelle Talos Extension Struktur mit korrekter Kernel Version
RUN KVER=$(cat /build/kernel_version.txt) && \
    mkdir -p /rootfs/rootfs/lib/modules/${KVER}/extras && \
    install -m 644 /build/driver/src/r8127.ko /rootfs/rootfs/lib/modules/${KVER}/extras/r8127.ko && \
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
# Stage 3: Extension Image (Scratch) - Talos Extension Format
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
