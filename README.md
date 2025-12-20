# Talos r8127 Extension

[![Build Talos r8127 Extension](https://github.com/DEIN-USER/talos-r8127-extension/actions/workflows/build-extension.yml/badge.svg)](https://github.com/DEIN-USER/talos-r8127-extension/actions/workflows/build-extension.yml)

Talos Linux System Extension für **Realtek RTL8127 10 Gigabit Ethernet** NICs.

## Unterstützte Hardware

| Chip | Geschwindigkeit | Status |
|------|-----------------|--------|
| RTL8127 | 10 GbE | ✅ Getestet |

**Getestete Geräte:**
- Minisforum MS-R1 (ARM64) - 2x RTL8127 10G NICs

## Architekturen

| Architektur | Status |
|-------------|--------|
| AMD64 (x86_64) | ✅ |
| ARM64 (aarch64) | ✅ |

## Quick Start

### 1. Talos Image Factory (Empfohlen)

1. Gehe zu [factory.talos.dev](https://factory.talos.dev)
2. Wähle deine Talos Version
3. Unter "System Extensions" → "Custom Extensions" hinzufügen:
   ```
   ghcr.io/DEIN-USER/talos-r8127-extension:v1.12.0-rc.1
   ```
4. ISO generieren und Node booten

### 2. Machine Config

```yaml
machine:
  install:
    extensions:
      - image: ghcr.io/DEIN-USER/talos-r8127-extension:v1.12.0-rc.1
  kernel:
    modules:
      - name: r8127
```

## Verfügbare Tags

| Tag | Beschreibung |
|-----|--------------|
| `v1.12.0-rc.1` | Für Talos v1.12.0-rc.1 (Kernel 6.12.6) |
| `latest` | Aktuellste Version |
| `v11.015.00` | Treiber-Version |

## Build

### Lokal

```bash
docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --build-arg KERNEL_VERSION=6.12.6 \
  -t ghcr.io/DEIN-USER/talos-r8127-extension:v1.12.0-rc.1 \
  --push .
```

### GitHub Actions

Der Workflow baut automatisch bei:
- Push auf `main`
- Tag Push (`v*`)
- Manueller Trigger mit Kernel/Talos Version

```bash
# Manueller Trigger via GitHub CLI
gh workflow run build-extension.yml \
  -f kernel_version=6.12.6 \
  -f talos_version=v1.12.0-rc.1
```

## Versionsmatrix

| Talos | Kernel | Extension Tag |
|-------|--------|---------------|
| v1.12.0-rc.1 | 6.12.6 | v1.12.0-rc.1 |
| v1.11.6 | 6.6.x | (nicht getestet) |

## Struktur

```
.
├── .github/
│   └── workflows/
│       └── build-extension.yml    # GitHub Actions Workflow
├── Dockerfile                      # Multi-Arch Build
├── manifest.yaml                   # Extension Metadata
├── r8127-11.015.00/               # Realtek Treiber Source
│   └── src/
│       └── *.c, *.h               # Kernel Module Source
└── README.md
```

## Lizenz

- **Treiber**: Realtek Semiconductor Corp. Proprietary License
- **Build Scripts**: MIT License

## Links

- [Talos Linux](https://www.talos.dev/)
- [Talos Image Factory](https://factory.talos.dev/)
- [Realtek Downloads](https://www.realtek.com/)

