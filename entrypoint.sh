#!/bin/sh

# env
TARGET_IP=${TARGET_IP:-127.0.0.1}
TARGET_PORT=${TARGET_PORT:-22}
SOCKS_PORT=${SOCKS_PORT:-1080}
SSH_KEY_PATH=${SSH_KEY_PATH:-/.keys/id_rsa}

# Function for create tunnel
create_tunnel() {
    echo "Creating SSH tunnel for SOCKS proxy..."
    ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -N -D 0.0.0.0:$SOCKS_PORT $TARGET_IP
}

# SSH tunnel
echo "Creating SSH tunnel for SOCKS proxy..."
# Loop to automatically reconnect the tunnel
while true; do
    create_tunnel
    echo "SSH tunnel dropped. Reconnecting..."
    sleep 5
done

# keep running
tail -f /dev/null