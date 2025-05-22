#!/bin/bash

# This script is the entrypoint for the Tailscale sidecar container.
# It sets up and starts the Tailscale client.

# --- Environment Variables (passed from docker-compose.yml or 'docker run -e') ---
# TS_AUTHKEY: Your Tailscale API key (required).
# TS_HOSTNAME (optional): Custom hostname for your Tailscale device.
# TS_TAGS (optional): Comma-separated list of tags (e.g., "tag:server,tag:flask").
# TS_EXTRA_ARGS (optional): Any additional arguments to pass to 'tailscale up'.

echo "Starting Tailscale sidecar..."

# Validate presence of the mandatory TS_AUTHKEY
if [ -z "$TS_AUTHKEY" ]; then
    echo "Error: TS_AUTHKEY environment variable is not set."
    echo "Please provide your Tailscale API key to connect to your Tailnet."
    exit 1
fi

# Construct the base 'tailscale up' command.
#   --authkey: Uses the provided API key for authentication.
#   --advertise-exit-node=false: Prevents this container from becoming an exit node.
#   --accept-routes=true: Accepts subnet routes advertised by other devices on your Tailnet.
#   --accept-dns=true: Accepts DNS configuration from Tailscale.
TAILSCALE_UP_CMD="tailscale up --authkey=${TS_AUTHKEY} --advertise-exit-node=false --accept-routes=true --accept-dns=true"

# Add custom hostname if provided
if [ -n "$TS_HOSTNAME" ]; then
    TAILSCALE_UP_CMD="${TAILSCALE_UP_CMD} --hostname=${TS_HOSTNAME}"
    echo "Using custom hostname: ${TS_HOSTNAME}"
fi

if [ -n "$TS_TAGS" ]; then
    TAILSCALE_UP_CMD="${TAILSCALE_UP_CMD} --advertise-tags=${TS_TAGS}"
    echo "Applying tags: ${TS_TAGS}"
fi

# Add tags if provided. Each tag needs its own '--tag=' argument.
# if [ -n "$TS_TAGS" ]; then
#     IFS=',' read -ra ADDR <<< "$TS_TAGS" # Split tags by comma
#     for i in "${ADDR[@]}"; do
#         TAILSCALE_UP_CMD="${TAILSCALE_UP_CMD} --tag=${i}"
#     done
#     echo "Applying tags: ${TS_TAGS}"
# fi

# Add any extra arguments specified.
if [ -n "$TS_EXTRA_ARGS" ]; then
    TAILSCALE_UP_CMD="${TAILSCALE_UP_CMD} ${TS_EXTRA_ARGS}"
    echo "Adding extra 'tailscale up' arguments: ${TS_EXTRA_ARGS}"
fi

# Start the Tailscale daemon in the background.
# This daemon manages the Tailscale network interface.
echo "Starting tailscaled daemon..."
tailscaled &

# Give the daemon a moment to initialize before trying to connect.
sleep 2

# Bring the Tailscale interface up and authenticate.
echo "Running Tailscale up command: ${TAILSCALE_UP_CMD}"
$TAILSCALE_UP_CMD

# Check if the 'tailscale up' command was successful.
if [ $? -eq 0 ]; then
    echo "Tailscale is up and connected to your Tailnet!"
    echo "Your Tailscale IP(s) for this container:"
    tailscale ip
    echo "Tailscale status:"
    tailscale status

    # Expose the Flask app service using tailscale serve
    echo "Exposing Flask app on port 80 via Tailscale Serve..."
    tailscale serve --tcp 80 tcp://localhost:5000 &
else
    echo "Error: 'tailscale up' failed. Check your Tailscale API key, hostname, tags, and container permissions."
    exit 1
fi

# Keep the container running indefinitely.
# 'tail -f /dev/null' keeps the script running without consuming CPU,
# ensuring the container stays alive and the tailscaled daemon continues to run.
tailscale status && tail -f /dev/null
