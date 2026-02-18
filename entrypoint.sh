#!/bin/sh

TARGET_IP=${TARGET_IP:-127.0.0.1}
TARGET_PORT=${TARGET_PORT:-22}
SOCKS_PORT=${SOCKS_PORT:-1080}
HTTP_PROXY_PORT=${HTTP_PROXY_PORT:-8118}
CHECK_INTERVAL=${CHECK_INTERVAL:-30}
CHECK_URL=${CHECK_URL:-https://api.ipify.org?format=json}
CHECK_TIMEOUT=${CHECK_TIMEOUT:-10}
SSH_KEY_PATH=${SSH_KEY_PATH:-/keys/id_rsa}

SSH_PID=""
HTTP_PID=""

print_banner() {
    if command -v figlet >/dev/null 2>&1; then
        figlet -w 120 "tunnely"
    else
        echo "tunnely"
    fi
    echo "Starting tunnely service..."
}

start_http_proxy() {
    cat > /tmp/privoxy.conf <<CONFIG
listen-address  0.0.0.0:${HTTP_PROXY_PORT}
forward-socks5t / 127.0.0.1:${SOCKS_PORT} .
daemon 0
logfile /dev/stdout
CONFIG

    privoxy --no-daemon /tmp/privoxy.conf &
    HTTP_PID=$!
    echo "HTTP proxy started on port ${HTTP_PROXY_PORT}"
}

stop_http_proxy() {
    if [ -n "$HTTP_PID" ] && kill -0 "$HTTP_PID" 2>/dev/null; then
        kill "$HTTP_PID"
        wait "$HTTP_PID" 2>/dev/null || true
    fi
}

start_ssh_tunnel() {
    echo "Starting SSH SOCKS tunnel to ${TARGET_IP}:${TARGET_PORT} on local port ${SOCKS_PORT}"
    ssh \
        -i "$SSH_KEY_PATH" \
        -o StrictHostKeyChecking=no \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=2 \
        -N \
        -D "0.0.0.0:${SOCKS_PORT}" \
        -p "$TARGET_PORT" \
        "$TARGET_IP" &

    SSH_PID=$!
}

stop_ssh_tunnel() {
    if [ -n "$SSH_PID" ] && kill -0 "$SSH_PID" 2>/dev/null; then
        kill "$SSH_PID"
        wait "$SSH_PID" 2>/dev/null || true
    fi

    SSH_PID=""
}

check_tunnel() {
    RESULT_JSON=$(curl \
        --silent \
        --show-error \
        --fail \
        --max-time "$CHECK_TIMEOUT" \
        --socks5-hostname "127.0.0.1:${SOCKS_PORT}" \
        "$CHECK_URL" 2>/dev/null)

    if [ -z "$RESULT_JSON" ]; then
        echo "Tunnel check failed: no response from ${CHECK_URL} through SOCKS proxy"
        return 1
    fi

    RESULT_IP=$(printf '%s' "$RESULT_JSON" | jq -er '.ip | strings | select(length > 0)' 2>/dev/null)
    if [ -z "$RESULT_IP" ]; then
        echo "Tunnel check failed: invalid ipify JSON response: ${RESULT_JSON}"
        return 1
    fi

    if ! printf '%s\n' "$RESULT_IP" | grep -Eq '^(([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'; then
        echo "Tunnel check failed: invalid IPv4 value from ipify: ${RESULT_IP}"
        return 1
    fi

    echo "Tunnel healthy via SSH SOCKS proxy, ipify IP: ${RESULT_IP}"
    return 0
}

cleanup() {
    echo "Stopping proxies..."
    stop_ssh_tunnel
    stop_http_proxy
    exit 0
}

trap cleanup INT TERM

print_banner

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found at ${SSH_KEY_PATH}"
    exit 1
fi

start_http_proxy

while true; do
    start_ssh_tunnel

    sleep 2
    if ! kill -0 "$SSH_PID" 2>/dev/null; then
        echo "SSH tunnel failed to start. Retrying in 5 seconds..."
        sleep 5
        continue
    fi

    while kill -0 "$SSH_PID" 2>/dev/null; do
        sleep "$CHECK_INTERVAL"

        if ! kill -0 "$SSH_PID" 2>/dev/null; then
            break
        fi

        if ! check_tunnel; then
            echo "Restarting SSH tunnel..."
            stop_ssh_tunnel
            break
        fi
    done

    echo "SSH tunnel disconnected. Reconnecting in 5 seconds..."
    stop_ssh_tunnel
    sleep 5
done
