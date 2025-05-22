# Docker Tailscale Sidecar

An example Docker container ("sidecar") running Tailscale and share its network with an application container. 

By utilizing a sidecar, you can see your app as if it's running on `localhost` and expose
it to your Tailnet using `tailscale serve`.

A basic Flask app (`flask-app/`) is offered as an example, but you can
swap it out with pretty much any HTTP service.

## Getting Started

1.  Clone this repository.
2.  Make sure you have Docker and Docker Compose installed.
3.  Tailscale API key is needed for unattended
    authentication. For automated setups, using ephemeral keys with pre-authorized tags
    is recommended.
4.  Copy `docker-compose.yml.example` to `docker-compose.yml`:
5.  Edit `docker-compose.yml` and replace `tskey-auth-YOUR_AUTH_KEY_HERE` with
    your actual Tailscale API key. If you used pre-authorized tags, make sure
    the `TS_TAGS` environment variable matches them.

## Running the Example

With `docker-compose.yml` configured:

1.  Build and run the containers:
    ```bash
    docker compose up --build
    ```
2.  Watch the logs (`docker compose logs tailscale-sidecar`) to see the
    Tailscale sidecar authenticate and connect.
3.  Once connected, the sidecar will expose the Flask app. By default, the
    `entrypoint.sh` in the sidecar is set up to expose the app listening on
    internal port 5000 onto Tailscale network port 80.
4.  Find the Tailscale IP address of the `my-flask-app-docker-sidecar` device in
    your [Tailscale Admin Console](https://login.tailscale.com/admin) or by
    running `tailscale status` on another device on your Tailnet.
5.  Access the Flask app from another device on your Tailnet using the sidecar's
    Tailscale IP and the exposed port (default: 80):
    `http://<tailscale_ip>:80/`.

## Docker Compose Setup Explained

Let's break down the `docker-compose.yml` file and the key networking bits:

```yaml
version: '3.8'

services:
  flask-app: # Your application service (rename this if you swap the app)
    build:
      context: ./flask-app # Path to your app's Dockerfile context
      dockerfile: Dockerfile
    container_name: my-flask-app
    # We *don't* expose the app's internal port (like 5000) directly to the host.
    # The sidecar will handle exposing it to Tailscale.
    networks:
      - app-net # Standard bridge network for internal container communication

  tailscale-sidecar:
    build:
      context: ./tailscale-sidecar # Path to the sidecar's Dockerfile context
      dockerfile: Dockerfile
    container_name: tailscale-app-sidecar

    # *** The Magic Bit: Shared Network Namespace ***
    # `network_mode: service:flask-app` makes the sidecar container *share the network stack*
    # of the `flask-app` container. Why? Because `tailscale serve` needs to proxy to
    # a service running on its *local* network interfaces (i.e., `localhost`).
    # By sharing the network namespace, `localhost:<app-port>` from inside the sidecar
    # *is* your app container!

network_mode: service:flask-app
    cap_add:
      - NET_ADMIN # Tailscale needs admin network privileges inside the container
    devices:
      - /dev/net/tun:/dev/net/tun # Needed for Tailscale/WireGuard to create its network interface
    environment:
      TS_AUTHKEY: "tskey-auth-YOUR_AUTH_KEY_HERE" # Your API key (use secrets in prod!)
      TS_HOSTNAME: "my-flask-app-docker-sidecar" # Custom hostname in Tailscale
      TS_TAGS: "tag:flask-app-service,tag:dockerized-app" # Tags for ACLs/organization
      # TS_EXTRA_ARGS is usually not needed for 'serve'
    depends_on:
      - flask-app # Make sure the app is running before the sidecar starts
    restart: unless-stopped # Keep the sidecar running
    # Optional: Use a volume to persist Tailscale state if not using ephemeral keys
    # volumes:
    #   - tailscale-state:/var/lib/tailscale

# Define Docker Networks
networks:
   app-net:
     driver: bridge # A standard bridge network

# Optional: Define volumes if used
# volumes:
#   tailscale-state:

```

### Learnings: Networking settings in `docker-compose` file

*   **`flask-app.networks: - app-net`**: Your app container lives on a standard
    Docker bridge network. It can talk to other containers on this network by
    their service name.
*   **`tailscale-sidecar.network_mode: service:flask-app`**: This is the core
    pattern! The sidecar doesn't get its *own* IP on `app-net`. Instead, it
    piggybacks on the `flask-app` container's network stack. This is why
    `localhost` inside the sidecar resolves to the `flask-app`.
*   **`tailscale-sidecar.cap_add: - NET_ADMIN`**: Tailscale needs to configure
    network interfaces and routing *within* the container. This capability gives
    it the power to do that.
*   **`tailscale-sidecar.devices: - /dev/net/tun:/dev/net/tun`**: Tailscale uses
    the TUN device to create its virtual network interface (`tailscale0`). This
    maps the necessary host device into the container.
*   **`networks.app-net.driver: bridge`**: Just your standard Docker bridge
    network definition.

These configurations work together to give the sidecar the necessary access to
your application's network stack to expose it via Tailscale.

## Exposing Services with `tailscale serve`

The modern way to advertise services is using the `tailscale serve` command.
It's simpler and replaces the older `--advertise-service` flag.

We run `tailscale serve` in the sidecar's `entrypoint.sh` script after Tailscale
connects. The command looks like this:

```bash
tailscale serve --tcp <external_port> tcp://localhost:<internal_port> &
```

*   The `&` at the end is important! It runs the command in the background so
    the entrypoint script can finish and the container stays running.

### Learnings: Addressing the `localhost` Limitation

Initially, you might think you could just use the service name, like `tailscale
serve --tcp 80 tcp://flask-app:5000`. But `tailscale serve` is designed to proxy
to services running on the *local* machine (or in our case, the local network
namespace). It expects `localhost` or `127.0.0.1`. Since `flask-app` is a
different host on the bridge network, that command wouldn't work from inside the
sidecar.

By using `network_mode: service:flask-app`, the sidecar *shares* the
`flask-app`'s network stack. Now, `localhost:5000` from inside the sidecar
*points directly to the Flask app* running in that shared namespace, making
`tailscale serve --tcp 80 tcp://localhost:5000` work perfectly!

### Learnings: Configuring the Exposed Port

Want your app accessible on a different port on your Tailnet? Easy! Just change
the `--tcp <external_port>` flag in the `tailscale serve` command within
`tailscale-sidecar/entrypoint.sh`.

*   `--tcp 80`: Exposes the service on port 80 on the sidecar's Tailscale IP.
*   `--tcp 5000`: Exposes the service on port 5000 on the sidecar's Tailscale
    IP.

The `tcp://localhost:<internal_port>` part should always match the port your
application is *actually* listening on *inside* its container (e.g., 5000 for
our Flask example). 