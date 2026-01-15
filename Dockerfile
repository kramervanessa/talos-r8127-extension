# =============================================================================
# Realtek r8127 10G NIC Driver - Talos System Extension
# Multi-Arch Build (ARM64 + AMD64)
# =============================================================================

# Talos 1.12.1 verwendet Kernel 6.18.2-talos
# Kernel-Version wird als Build-Arg übergeben (z.B. 6.18.2)
ARG KERNEL_VERSION=6.18.2

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

# Download Kernel Source
# Kernel.org URL-Struktur: v6.x für alle 6.x.y Versionen
RUN echo "Downloading kernel ${KERNEL_VERSION}..." && \
    KERNEL_MAJOR=$(echo "${KERNEL_VERSION}" | cut -d. -f1) && \
    mkdir -p /usr/src && \
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VERSION}.tar.xz" -O /tmp/linux.tar.xz && \
    tar xf /tmp/linux.tar.xz -C /usr/src && \
    mv /usr/src/linux-* /usr/src/linux && \
    rm /tmp/linux.tar.xz && \
    echo "Kernel ${KERNEL_VERSION} downloaded"

# Konfiguriere Kernel fuer Module Build
# Bestimme Kernel-Version dynamisch und setze EXTRAVERSION
RUN cd /usr/src/linux && \
    echo "Configuring kernel for ${TARGETARCH}..." && \
    make defconfig && \
    scripts/config --disable CONFIG_MODVERSIONS && \
    scripts/config --enable CONFIG_MODULES && \
    scripts/config --enable CONFIG_MODULE_UNLOAD && \
    # Setze EXTRAVERSION passend zur Talos Version (-talos, ohne PATCH-Version)
    # Talos verwendet z.B. 6.18.2-talos, nicht 6.18.2.2-talos
    sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = -talos/" Makefile && \
    make olddefconfig && \
    make modules_prepare && \
    touch Module.symvers && \
    # Zeige resultierende Kernel Version
    FINAL_KVER=$(cat include/config/kernel.release) && \
    echo "Final kernel version: ${FINAL_KVER}" && \
    echo "${FINAL_KVER}" > /tmp/kernel_version.txt && \
    echo "Kernel configured"

# Build Kernel Module
RUN cd /build/driver/src && \
    echo "Building r8127 driver..." && \
    KBUILD_MODPOST_WARN=1 make -C /usr/src/linux M=$(pwd) modules && \
    ls -la *.ko && \
    echo "Build successful!"

# Erstelle Talos Extension Struktur mit korrekter Kernel Version
# Talos Extension Format:
#   /manifest.yaml
#   /rootfs/usr/lib/modules/<kernel-version>/kernel/...
# Wichtig: Module müssen in kernel/ Unterverzeichnis sein, damit depmod sie findet
RUN KVER=$(cat /tmp/kernel_version.txt) && \
    echo "Installing module for kernel version: ${KVER}" && \
    # Erstelle korrekte Verzeichnisstruktur für Kernel-Module
    MODULE_DIR="/extension/rootfs/usr/lib/modules/${KVER}/kernel/drivers/net/ethernet/realtek" && \
    mkdir -p ${MODULE_DIR} && \
    install -m 644 /build/driver/src/r8127.ko ${MODULE_DIR}/r8127.ko && \
    # Generiere modules.dep, modules.alias, modules.symbols etc.
    # depmod benötigt das komplette /usr/lib/modules/<kernel-version> Verzeichnis
    echo "Generating modules.dep for kernel ${KVER}..." && \
    depmod -b /extension/rootfs/usr -F /usr/src/linux/include/config/kernel.release -E /usr/src/linux/Module.symvers ${KVER} 2>&1 || \
    depmod -b /extension/rootfs/usr ${KVER} 2>&1 || \
    (echo "Warning: depmod failed, trying alternative method..." && \
     cd /extension/rootfs/usr/lib/modules/${KVER} && \
     depmod -b /extension/rootfs/usr ${KVER} 2>&1) && \
    # Verifiziere dass modules.dep erstellt wurde
    if [ -f "/extension/rootfs/usr/lib/modules/${KVER}/modules.dep" ]; then \
        echo "✓ modules.dep created successfully" && \
        head -3 /extension/rootfs/usr/lib/modules/${KVER}/modules.dep; \
    else \
        echo "⚠ Warning: modules.dep not found, creating minimal version" && \
        echo "kernel/drivers/net/ethernet/realtek/r8127.ko:" > /extension/rootfs/usr/lib/modules/${KVER}/modules.dep; \
    fi && \
    echo "Installed r8127.ko for kernel ${KVER} at ${MODULE_DIR}"

# Erstelle manifest.yaml fuer Talos Extension (im Root der Extension)
RUN cat > /extension/manifest.yaml << 'EOF'
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
      version: ">= v1.12.0 < v1.13.0"
    kernel:
      version: "6.18.x"
EOF

# Zeige Extension Struktur
RUN echo "=== Extension Structure ===" && find /extension -type f

# -----------------------------------------------------------------------------
# Stage 2: Extension Image (Scratch) - Talos Extension Format
# -----------------------------------------------------------------------------
FROM scratch AS extension

# Kopiere Extension Struktur (manifest.yaml im Root + rootfs/ Ordner)
COPY --from=builder /extension/ /

# Metadata Labels
LABEL org.opencontainers.image.title="r8127"
LABEL org.opencontainers.image.description="Realtek RTL8127 10 Gigabit Ethernet driver for Talos Linux"
LABEL org.opencontainers.image.version="11.015.00"
LABEL org.opencontainers.image.authors="Realtek / Vanessa Kramer"
LABEL io.talos.extension.name="r8127"
LABEL io.talos.extension.version="v11.015.00"
