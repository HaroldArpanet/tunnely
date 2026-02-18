# tunnely

A lightweight Docker service that keeps an SSH SOCKS tunnel alive and exposes both:
- a SOCKS5 proxy (from SSH dynamic forwarding)
- an HTTP proxy (via Privoxy forwarding to SOCKS)

## Features
- Automatic SSH reconnect when tunnel drops
- Tunnel health-check every 30 seconds (configurable)
- Health-check sends request to `api.ipify.org?format=json` through SOCKS tunnel
- Health-check validates ipify JSON response (`{"ip":"x.x.x.x"}` + valid IPv4)
- If check fails or response is invalid, SSH tunnel is restarted

## Environment variables
- `TARGET_IP`: SSH target host/IP
- `TARGET_PORT` (default `22`): SSH port
- `SOCKS_PORT` (default `1080`): local SOCKS5 proxy port
- `HTTP_PROXY_PORT` (default `8118`): local HTTP proxy port
- `CHECK_URL` (default `https://api.ipify.org?format=json`): health-check endpoint
- `CHECK_INTERVAL` (default `30`): health-check interval in seconds
- `CHECK_TIMEOUT` (default `10`): health-check request timeout in seconds

## Notes
- Mount your SSH private key into `./ssh-keys/id_rsa` (read-only in container).
