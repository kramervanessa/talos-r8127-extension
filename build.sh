#!/bin/bash
# =============================================================================
# Build Realtek r8127 Talos System Extension
# Multi-Arch: ARM64 + AMD64
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVER_DIR="${SCRIPT_DIR}/.."
TALOS_VERSION="${TALOS_VERSION:-v1.12.0-rc.1}"
EXTENSION_VERSION="v11.015.00"
REGISTRY="${REGISTRY:-ghcr.io/kramervanessa}"
IMAGE_NAME="r8127-talos-extension"

echo "=============================================="
echo "Building r8127 Talos System Extension"
echo "=============================================="
echo "Talos Version: ${TALOS_VERSION}"
echo "Extension Version: ${EXTENSION_VERSION}"
echo "Registry: ${REGISTRY}"
echo ""

# Pruefe ob Treiber vorhanden
if [ ! -d "${DRIVER_DIR}/r8127-11.015.00" ]; then
    echo "ERROR: Treiber nicht gefunden!"
    echo "Bitte r8127-11.015.00.tar.bz2 entpacken"
    exit 1
fi

# Kopiere Treiber in Build Context
cp -r "${DRIVER_DIR}/r8127-11.015.00" "${SCRIPT_DIR}/"

# Erstelle Multi-Arch Builder (falls nicht vorhanden)
echo "=== Setup Multi-Arch Builder ==="
sudo docker buildx create --name talos-builder --use 2>/dev/null || \
    sudo docker buildx use talos-builder

# Aktiviere QEMU fuer Cross-Compilation
echo "=== Setup QEMU ==="
sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || true

# Build fuer beide Architekturen
echo ""
echo "=== Building Multi-Arch Image ==="
echo "Platforms: linux/arm64, linux/amd64"
echo ""

sudo docker buildx build \
    --platform linux/arm64,linux/amd64 \
    --build-arg TALOS_VERSION="${TALOS_VERSION}" \
    -t "${REGISTRY}/${IMAGE_NAME}:${EXTENSION_VERSION}" \
    -t "${REGISTRY}/${IMAGE_NAME}:latest" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "${SCRIPT_DIR}" \
    --push

echo ""
echo "=============================================="
echo "Build erfolgreich!"
echo "=============================================="
echo ""
echo "Image: ${REGISTRY}/${IMAGE_NAME}:${EXTENSION_VERSION}"
echo ""
echo "Naechste Schritte:"
echo "1. Gehe zu https://factory.talos.dev"
echo "2. Waehle Talos ${TALOS_VERSION}"
echo "3. Fuege Custom Extension hinzu:"
echo "   ${REGISTRY}/${IMAGE_NAME}:${EXTENSION_VERSION}"
echo "4. Generiere neues ISO"
echo ""

# Cleanup
rm -rf "${SCRIPT_DIR}/r8127-11.015.00"


