# Talos r8127 Extension

[![Build Talos r8127 Extension](https://github.com/kramervanessa/talos-r8127-extension/actions/workflows/build-extension.yml/badge.svg)](https://github.com/kramervanessa/talos-r8127-extension/actions/workflows/build-extension.yml)

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
   ghcr.io/kramervanessa/talos-r8127-extension:v1.12.1
   ```
4. ISO generieren und Node booten

### 2. Machine Config

```yaml
machine:
  install:
    extensions:
      - image: ghcr.io/kramervanessa/talos-r8127-extension:v1.12.1
  kernel:
    modules:
      - name: r8127
```

**Wichtig:** Das ISO enthält bereits die Extension und blacklistet den `r8169` Treiber automatisch. 
Das `r8127` Modul wird automatisch geladen wenn es in der Machine Config spezifiziert ist.

**Für manuelle Installation (ohne ISO):**
Wenn du ein Standard-Talos ISO verwendest und die Extension manuell hinzufügst, musst du zusätzlich den r8169 Treiber blockieren:

```yaml
machine:
  install:
    extensions:
      - image: ghcr.io/kramervanessa/talos-r8127-extension:v1.12.1
  kernel:
    modules:
      - name: r8127
    parameters:
      - key: modprobe.blacklist
        value: r8169
```

## Verfügbare Tags

| Tag | Beschreibung |
|-----|--------------|
| `v1.12.1` | Für Talos v1.12.1 (Kernel 6.18.2) |
| `latest` | Aktuellste Version |
| `v11.015.00` | Treiber-Version |

**Hinweis**: Alle Images sind mit Cosign signiert für sichere Installation.

## Build

### Lokal

```bash
docker buildx build \
  --platform linux/arm64,linux/amd64 \
  --build-arg KERNEL_VERSION=6.18.2 \
  -t ghcr.io/kramervanessa/talos-r8127-extension:v1.12.1 \
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
  -f kernel_version=6.18.2 \
  -f talos_version=v1.12.1
```

## Versionsmatrix

| Talos | Kernel | Extension Tag | Status |
|-------|--------|---------------|--------|
| v1.12.1 | 6.18.2 | v1.12.1 | ✅ Aktuell |
| v1.12.0 | 6.18.0 | v1.12.0 | ✅ Unterstützt |
| v1.12.0-rc.1 | 6.18.0 | v1.12.0-rc.1 | ⚠️ Veraltet |

## Sicherheit und Signierung

Alle Extension-Images werden automatisch mit **Cosign** (Keyless Signing) signiert:

- ✅ **Keyless Signing**: Nutzt GitHub Actions OIDC für sichere Signierung ohne Key-Management
- ✅ **Automatische Signatur**: Bei jedem Push/Tag wird das Image signiert
- ✅ **Verifizierung**: Images können mit `cosign verify` geprüft werden

**Signatur-Verifizierung**:

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/kramervanessa/talos-r8127-extension:v1.12.1
```

## Struktur

```
.
├── .github/
│   └── workflows/
│       └── build-extension.yml    # GitHub Actions Workflow (mit Cosign)
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

