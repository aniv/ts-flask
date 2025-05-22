# Dockerfile for a generic Tailscale sidecar
# This sidecar runs the Tailscale client to make an associated application
# accessible on your Tailnet.

# Use a lean Debian-based image as recommended by Tailscale for stability and size.
FROM debian:bullseye-slim

# Install necessary packages:
#   - curl: For downloading Tailscale's GPG key and repository list.
#   - iproute2: For network utilities (though not strictly required by Tailscale itself, good for debugging).
#   - ca-certificates: For validating SSL certificates when fetching packages.
#   - net-tools: Contains ifconfig, route, etc., useful for debugging.
#   - nftables: Some Tailscale configurations might interact with nftables.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        iproute2 \
        ca-certificates \
        net-tools \
        gnupg \
        nftables && \
    # Add Tailscale's official GPG key
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.gpg | apt-key add - && \
    # Add Tailscale's official repository list
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.list | tee /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && \
    # Install the Tailscale client
    apt-get install -y --no-install-recommends tailscale && \
    # Clean up APT cache to reduce image size
    rm -rf /var/lib/apt/lists/*

# Copy the custom entrypoint script into the container and make it executable.
# This script will handle the Tailscale configuration and startup.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint script as the default command to run when the container starts.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Note: We do not EXPOSE any ports here directly, as the primary access will be
# via the Tailscale IP on the Tailnet, not through Docker's host-port mapping.
# The Flask app itself will expose its port internally on the Docker network.
