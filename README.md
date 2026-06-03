# EasyTier OPNsense Plugin

An OPNsense plugin to install and manage [EasyTier](https://easytier.rs), a simple, decentralized mesh VPN with WireGuard support. EasyTier creates peer-to-peer overlay networks that connect devices across different networks with NAT traversal, smart routing, and encryption.

## Features

- **Web UI Management** — Configure EasyTier from the OPNsense GUI under VPN → EasyTier
- **Service Control** — Start, stop, restart, and monitor the EasyTier service
- **Full Configuration** — All major EasyTier options exposed through the web interface
- **Auto-generated Config** — Configuration file is automatically generated from UI settings
- **API Access** — RESTful API for automation and scripting

## Prerequisites

- OPNsense 23.7 or later
- `easytier-core` binary (FreeBSD/amd64) — download from [EasyTier Releases](https://github.com/EasyTier/EasyTier/releases)

## Installation

### Step 1: Install the EasyTier Binary

Download the FreeBSD/amd64 release of `easytier-core` and place it on your OPNsense system:

```bash
# Download the latest release (adjust version as needed)
fetch https://github.com/EasyTier/EasyTier/releases/download/v2.x.x/easytier-freebsd-x86_64-v2.x.x.zip

# Extract and install
unzip easytier-freebsd-x86_64-v2.x.x.zip
cp easytier-core /usr/local/bin/
chmod +x /usr/local/bin/easytier-core
```

Verify the binary works:

```bash
easytier-core --help
```

### Step 2: Install the Plugin

Copy the plugin files to your OPNsense system:

```bash
# Clone or download this repository
git clone https://github.com/shen390s/easytier_opnsense_plugin.git

# Copy plugin files to the OPNsense filesystem
cp -r net/easytier/src/etc/rc.d/easytier /usr/local/etc/rc.d/
cp -r net/easytier/src/opnsense/ /usr/local/opnsense/

# Set correct permissions
chmod +x /usr/local/etc/rc.d/easytier
chmod +x /usr/local/opnsense/scripts/OPNsense/EasyTier/reconfigure.sh

# Restart configd to pick up new actions
service configd restart
```

### Step 3: Refresh the UI

Navigate to your OPNsense web interface. The new menu item will appear under **VPN → EasyTier**.

## Configuration Guide

### Basic Setup — Join a Network

The simplest configuration connects this node to an existing EasyTier network:

1. Go to **VPN → EasyTier → General**
2. Check **Enable EasyTier**
3. Set **Network Name** — e.g., `my-network`
4. Set **Network Secret** — e.g., `my-secret-key`
5. Set **IPv4 Address** — e.g., `10.144.144.1/24` (or check **Use DHCP**)
6. Set **Peer Nodes** — e.g., `udp://192.168.1.100:11010` (address of another node)
7. Click **Save**

### Configuration Options Reference

| Field | Description | Example |
|-------|-------------|---------|
| **Enable EasyTier** | Enable/disable the service | Checked |
| **Network Name** | Virtual network identifier; nodes with the same name + secret join together | `office-network` |
| **Network Secret** | Shared secret for network authentication | `s3cur3-p@ss` |
| **Hostname** | Optional friendly name for this node | `opnsense-gw` |
| **IPv4 Address** | Static virtual IP in CIDR notation | `10.144.144.1/24` |
| **Use DHCP** | Auto-assign virtual IP from EasyTier DHCP | Checked |
| **Default Protocol** | Default transport protocol | `udp`, `tcp`, `ws`, `wss` |
| **Listeners** | Addresses this node listens on (comma-separated) | `udp://0.0.0.0:11010, tcp://0.0.0.0:11011` |
| **Peer Nodes** | Remote peers to connect to (comma-separated) | `udp://1.2.3.4:11010, tcp://example.com:11010` |
| **Proxy Networks** | Subnets to expose to the VPN (comma-separated CIDR) | `192.168.1.0/24, 10.0.0.0/16` |
| **RPC Portal** | Management API address | `127.0.0.1:15888` |
| **External Node** | Public relay server URL | `tcp://public-server.example.com:11010` |
| **Relay All Peer RPC** | Act as relay for all peer RPC traffic | Unchecked |
| **Relay Network Whitelist** | Networks allowed to relay through this node | `network-a, network-b` |
| **Disable P2P** | Force relay-only mode (no direct connections) | Unchecked |
| **Disable UDP Hole Punching** | Disable NAT traversal via UDP | Unchecked |
| **Multi-Thread** | Use multi-threaded runtime for performance | Checked |
| **Latency First** | Prefer low-latency routes over bandwidth | Unchecked |
| **Enable Exit Node** | Allow this node to route internet traffic | Unchecked |
| **No TUN Device** | Run without TUN (relay-only or SOCKS5 mode) | Unchecked |
| **SOCKS5 Portal** | SOCKS5 proxy listen address | `127.0.0.1:1080` |

### Common Scenarios

#### Scenario 1: Two-Node Direct Connection

**Node A (OPNsense):**
- Network Name: `home-office`
- Network Secret: `shared-key-123`
- IPv4: `10.144.144.1/24`
- Listeners: `udp://0.0.0.0:11010`

**Node B (Remote machine):**
```bash
easytier-core --network-name home-office --network-secret shared-key-123 \
  --ipv4 10.144.144.2/24 --peers udp://<NodeA-Public-IP>:11010
```

#### Scenario 2: Subnet Proxy (Site-to-Site)

Expose the local LAN `192.168.1.0/24` to the EasyTier network:

- Network Name: `company`
- Network Secret: `corp-secret`
- IPv4: `10.144.144.1/24`
- Listeners: `udp://0.0.0.0:11010`
- Proxy Networks: `192.168.1.0/24`

Remote nodes will be able to access `192.168.1.x` hosts through this OPNsense gateway.

#### Scenario 3: Using a Public Relay Server

When both nodes are behind NAT without port forwarding:

- Network Name: `mobile-net`
- Network Secret: `my-secret`
- IPv4: `10.144.144.1/24`
- Peer Nodes: `tcp://relay.example.com:11010`

#### Scenario 4: SOCKS5 Proxy Mode (No Root/TUN)

Run EasyTier without a TUN device, exposing a local SOCKS5 proxy:

- Enable EasyTier: Checked
- Network Name: `proxy-net`
- Network Secret: `proxy-secret`
- Peer Nodes: `udp://peer-address:11010`
- No TUN Device: Checked
- SOCKS5 Portal: `127.0.0.1:1080`

Applications can then use `socks5://127.0.0.1:1080` to access the EasyTier network.

## API Usage

The plugin exposes a REST API for automation:

```bash
# Get current configuration
curl -k -u admin:password https://opnsense/api/easytier/general/get

# Update configuration
curl -k -u admin:password -X POST https://opnsense/api/easytier/general/set \
  -d '{"general":{"enabled":"1","network_name":"my-net","network_secret":"secret"}}'

# Reconfigure (apply changes)
curl -k -u admin:password -X POST https://opnsense/api/easytier/service/reconfigure

# Start service
curl -k -u admin:password -X POST https://opnsense/api/easytier/service/start

# Stop service
curl -k -u admin:password -X POST https://opnsense/api/easytier/service/stop

# Get service status
curl -k -u admin:password https://opnsense/api/easytier/service/status
```

## Troubleshooting

### Service won't start

1. Verify the binary is installed:
   ```bash
   ls -la /usr/local/bin/easytier-core
   ```

2. Check the configuration file was generated:
   ```bash
   cat /usr/local/etc/easytier.conf
   ```

3. Try running manually to see errors:
   ```bash
   /usr/local/bin/easytier-core --config-file /usr/local/etc/easytier.conf
   ```

4. Check system logs:
   ```bash
   tail -f /var/log/messages | grep easytier
   ```

### Cannot connect to peers

1. Ensure firewall rules allow the listener port (default UDP/TCP 11010)
2. Go to **Firewall → Rules → WAN** and add a rule to pass traffic on port 11010
3. Verify peer addresses are correct and reachable
4. If behind NAT, try using a public relay server via the **External Node** field

### Plugin not showing in menu

1. Restart configd:
   ```bash
   service configd restart
   ```

2. Clear the UI cache by navigating to **System → Firmware → Status** and clicking "Audit now"

3. Verify file permissions:
   ```bash
   chown -R root:wheel /usr/local/opnsense/mvc/app/controllers/OPNsense/EasyTier/
   chown -R root:wheel /usr/local/opnsense/mvc/app/models/OPNsense/EasyTier/
   chown -R root:wheel /usr/local/opnsense/mvc/app/views/OPNsense/EasyTier/
   ```

### Check EasyTier node status

Use `easytier-cli` to inspect the running node:

```bash
# Show peer list
easytier-cli --rpc-portal 127.0.0.1:15888 peer

# Show routes
easytier-cli --rpc-portal 127.0.0.1:15888 route

# Show connector status
easytier-cli --rpc-portal 127.0.0.1:15888 connector
```

## File Locations

| File | Purpose |
|------|---------|
| `/usr/local/bin/easytier-core` | EasyTier daemon binary |
| `/usr/local/etc/easytier.conf` | Generated configuration file |
| `/usr/local/etc/rc.d/easytier` | Service control script |
| `/var/run/easytier.pid` | PID file |
| `/usr/local/opnsense/scripts/OPNsense/EasyTier/reconfigure.sh` | Reconfigure handler |

## Uninstallation

```bash
# Stop the service
service easytier stop

# Remove plugin files
rm -rf /usr/local/opnsense/mvc/app/controllers/OPNsense/EasyTier/
rm -rf /usr/local/opnsense/mvc/app/models/OPNsense/EasyTier/
rm -rf /usr/local/opnsense/mvc/app/views/OPNsense/EasyTier/
rm -rf /usr/local/opnsense/scripts/OPNsense/EasyTier/
rm -rf /usr/local/opnsense/service/conf/actions.d/actions_easytier.conf
rm -rf /usr/local/opnsense/service/templates/OPNsense/EasyTier/
rm -f /usr/local/etc/rc.d/easytier
rm -f /usr/local/etc/easytier.conf

# Optionally remove the binary
rm -f /usr/local/bin/easytier-core

# Restart configd
service configd restart
```

## License

This project is licensed under the BSD 2-Clause License. See [LICENSE](LICENSE) for details.

## Links

- [EasyTier Official Website](https://easytier.rs)
- [EasyTier GitHub](https://github.com/EasyTier/EasyTier)
- [OPNsense Plugin Development Guide](https://docs.opnsense.org/development/examples/helloworld.html)
