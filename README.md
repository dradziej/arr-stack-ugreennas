# Media Automation Stack for Ugreen NAS

A complete, production-ready Docker Compose stack for automated media management with VPN routing, SSL certificates, and remote access.

**Tested on Ugreen NAS DXP4800+** but should work on any Docker host (Synology, QNAP, Linux server, etc.).

## Legal Notice

This project provides configuration files for **legal, open-source software** designed for managing personal media libraries. All included tools have legitimate purposes - see **[LEGAL.md](docs/LEGAL.md)** for details on intended use, user responsibilities, and disclaimer.

---

## Getting Started

**[Setup Guide](docs/SETUP.md)** - Complete step-by-step instructions for deployment.

<details>
<summary>Using Claude Code for guided setup (optional)</summary>

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) can walk you through deployment step-by-step, executing commands and troubleshooting as you go.

**VS Code / Cursor:** Install the Claude extension, open this folder, and start a chat.

**Terminal:**
```bash
npm install -g @anthropic-ai/claude-code
cd arr-stack-ugreennas && claude
```

Ask Claude to help deploy the stack - it reads the [`.claude/instructions.md`](.claude/instructions.md) file automatically.

</details>

---

## Features

- **VPN-protected networking** via Gluetun + Surfshark for privacy
- **Automated SSL/TLS** certificates via Traefik + Cloudflare
- **Media library management** with Sonarr, Radarr, Prowlarr, Bazarr
- **Media streaming** with Jellyfin (or Plex - see below)
- **Request management** with Jellyseerr (or Overseerr for Plex)
- **Remote access** via WireGuard VPN
- **Ad-blocking DNS** with Pi-hole

## Services

### `docker-compose.traefik.yml` - Infrastructure

| Service | Description | Local Port | Domain URL |
|---------|-------------|------------|------------|
| **Traefik** | Reverse proxy with automatic SSL | 8080, 8443, 9090 | traefik.yourdomain.com |

### `docker-compose.cloudflared.yml` - External Access *(optional - for remote access)*

| Service | Description | Local Port | Domain URL |
|---------|-------------|------------|------------|
| **Cloudflared** | Cloudflare Tunnel for remote access | - | Internal |

### `docker-compose.arr-stack.yml` - Media Stack

**Remote access** (via Cloudflare Tunnel):

| Service | Description | Local Port | Domain URL |
|---------|-------------|------------|------------|
| **Jellyfin** | Media streaming server | 8096 | jellyfin.yourdomain.com |
| **Jellyseerr** | Media request system | 5055 | jellyseerr.yourdomain.com |
| **WireGuard** | VPN server for remote access | 51820/udp | wg.yourdomain.com |

**Local-only** (access via NAS_IP:PORT or WireGuard VPN):

| Service | Description | Local Port |
|---------|-------------|------------|
| **Gluetun** | VPN gateway for network privacy | - |
| **qBittorrent** | BitTorrent client (VueTorrent UI) | 8085 |
| **Sonarr** | TV show library management | 8989 |
| **Radarr** | Movie library management | 7878 |
| **Prowlarr** | Search aggregator | 9696 |
| **Bazarr** | Subtitle management | 6767 |
| **Pi-hole** | DNS + Ad-blocking | 53, 80 |
| **FlareSolverr** | CAPTCHA solver | 8191 |

> **Why local-only?** These services default to "no login required from local network". Cloudflare Tunnel traffic appears as local, bypassing auth entirely. Use Jellyseerr for remote media requests. For remote admin access, connect via WireGuard first.
>
> **Don't need all these?** Remove any service by deleting its section from the compose file. Core dependency: Gluetun (VPN gateway).
>
> **Prefer Plex?** See `docker-compose.plex-arr-stack.yml` for an untested Plex/Overseerr variant.

### `docker-compose.utilities.yml` - Optional Utilities

| Service | Description | Local Access | Remote Access |
|---------|-------------|--------------|---------------|
| **deunhealth** | Auto-restart services if VPN drops and recovers | - | Internal |
| **Uptime Kuma** | Service monitoring dashboard | http://NAS_IP:3001 | Via WireGuard |
| **duc** | Disk usage analyzer (treemap UI) | http://NAS_IP:8838 | Via WireGuard |

> **Security note:** Utilities are local-only by default. duc has no authentication and exposes filesystem structure. Uptime Kuma exposes infrastructure details. Access remotely via WireGuard VPN.

## Deployment Options

### Option A: Remote Access (Recommended)

Access your services from anywhere - phone on mobile data, travelling, etc. Requires a cheap domain (~$10/year):
- **Remote access** from anywhere via Cloudflare Tunnel
- **SSL/HTTPS** with automatic certificates
- **Pretty URLs** like `jellyfin.yourdomain.com`
- **WireGuard VPN** for secure access to your home network

**Requirements:** Domain name, Cloudflare account (free), VPN subscription

> **Cloudflare:** This stack is configured for Cloudflare (DNS + Tunnel). Other DNS providers work but you'll need to modify `docker-compose.traefik.yml` and `traefik/traefik.yml`. See [Traefik ACME docs](https://doc.traefik.io/traefik/https/acme/).
>
> **VPN:** Configured for Surfshark but Gluetun supports 30+ providers (NordVPN, PIA, Mullvad, etc.). See [Gluetun providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers).

### Option B: Local Network Only (No Domain)

Skip the domain and access services directly via IP:port. All services work out of the box:
- `http://NAS_IP:8096` → Jellyfin
- `http://NAS_IP:5055` → Jellyseerr
- `http://NAS_IP:8989` → Sonarr
- `http://NAS_IP:7878` → Radarr
- `http://NAS_IP:9696` → Prowlarr
- `http://NAS_IP:8085` → qBittorrent
- `http://NAS_IP:6767` → Bazarr
- `http://NAS_IP:53` → Pi-hole DNS

**What works:** All media automation, VPN-protected downloads, Pi-hole DNS, local streaming

**What you lose:** Remote access, HTTPS, subdomain routing, WireGuard remote VPN

**To deploy local-only:**
1. Skip `docker-compose.traefik.yml` and `docker-compose.cloudflared.yml`
2. Deploy: `docker compose -f docker-compose.arr-stack.yml up -d`
3. Access via `http://NAS_IP:PORT`


## Security

**Many services default to NO authentication!** After deployment, enable authentication on:

| Service | Default Auth | Action Required |
|---------|--------------|-----------------|
| Bazarr | Disabled | Enable Forms auth, regenerate API key |
| Sonarr/Radarr/Prowlarr | Disabled for Local | Set to Forms + Enabled |
| qBittorrent | Bypass localhost | Disable bypass, change default password |

**Cloudflare Tunnel warning**: Tunnel traffic appears as localhost, bypassing "Disabled for Local Addresses" auth.

See [Security section](docs/SETUP.md#59-security-enable-authentication) in Setup Guide for details.

## License

Documentation, configuration files, and examples in this repository are licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) (Attribution-NonCommercial). Individual software components (Sonarr, Radarr, Jellyfin, etc.) retain their own licenses.

## Acknowledgments

Forked from [TheRealCodeVoyage/arr-stack-setup-with-pihole](https://github.com/TheRealCodeVoyage/arr-stack-setup-with-pihole). Thanks to [@benjamin-awd](https://github.com/benjamin-awd) for VPN config improvements.
