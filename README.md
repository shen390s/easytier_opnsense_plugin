# EasyTier OPNsense Plugin

An OPNsense plugin to install and manage [EasyTier](https://easytier.rs), a simple, decentralized mesh VPN with WireGuard support. EasyTier creates peer-to-peer overlay networks that connect devices across different networks with NAT traversal, smart routing, and encryption.

## Features

- **Fully Automated Installation** — Single command installs both the EasyTier binary and OPNsense plugin
- **Version Selection** — Install any EasyTier release version by passing it as a parameter
- **Web UI Management** — Configure EasyTier from the OPNsense GUI under VPN → EasyTier
- **Service Control** — Start, stop, restart, and monitor the EasyTier service
- **Full Configuration** — All major EasyTier options exposed through the web interface
- **API Access** — RESTful API for automation and scripting
- **Clean Uninstall** — Single command to completely remove the plugin and binaries

## Quick Start

### Method 1: Remote Install (Recommended)

Clone the repo on your **local PC** and deploy to the OPNsense box over SSH:

```bash
# On your local machine (Linux, macOS, or Windows WSL)
git clone https://github.com/shen390s/easytier_opnsense_plugin.git
cd easytier_opnsense_plugin

# Install to remote OPNsense box
./remote-install.sh -H root@192.168.1.1 -v 2.6.4
```

That's it! The remote installer will:
1. Connect to your OPNsense box via SSH
2. Auto-detect the FreeBSD version on the remote system
3. Download the correct EasyTier binary locally from GitHub
4. Upload binaries and plugin files to the OPNsense box
5. Deploy everything and restart configd

#### Remote Install Options

```bash
# Basic remote install (auto-detects FreeBSD version)
./remote-install.sh -H root@192.168.1.1 -v 2.6.4

# With custom SSH port
./remote-install.sh -H root@192.168.1.1 -v 2.6.4 -p 2222

# With SSH key and explicit FreeBSD version
./remote-install.sh -H root@opnsense.local -v 2.6.4 -f 14.2 -i ~/.ssh/opnsense_key

# Remote uninstall
./remote-install.sh -H root@192.168.1.1 -u

# Show help
./remote-install.sh -h
```

#### Remote Install Parameters

| Flag | Description | Default |
|------|-------------|---------|
| `-H HOST` | Remote SSH host (required, e.g., `root@192.168.1.1`) | — |
| `-v VERSION` | EasyTier version (required) | — |
| `-p PORT` | SSH port | `22` |
| `-f FBSD_VER` | FreeBSD version override | Auto-detected |
| `-a ARCH` | Architecture | `x86_64` |
| `-i KEY` | SSH private key file | — |
| `-u` | Uninstall from remote | — |

### Method 2: Local Install (On the OPNsense Box)

If you prefer to run directly on the OPNsense system:

```bash
# SSH into your OPNsense box first
ssh root@192.168.1.1

# Clone and install
git clone https://github.com/shen390s/easytier_opnsense_plugin.git
cd easytier_opnsense_plugin
./install.sh -v 2.6.4
```

#### Local Install Options

```bash
# Install with explicit FreeBSD version
./install.sh -v 2.6.4 -f 14.2

# Install for a different architecture
./install.sh -v 2.6.4 -f 13.2 -a aarch64

# Show help
./install.sh -h

# Uninstall everything
./install.sh -u
```

### Upgrade

To upgrade to a newer version of EasyTier:

```bash
# Remote upgrade from local PC
cd easytier_opnsense_plugin
git pull
./remote-install.sh -H root@192.168.1.1 -v 2.6.4

# Or local upgrade on OPNsense box
cd easytier_opnsense_plugin
git pull
./install.sh -v 2.6.4
```

The installer will replace the existing binaries and plugin files.

### Uninstall

```bash
# Remote uninstall
./remote-install.sh -H root@192.168.1.1 -u

# Or local uninstall on OPNsense box
./install.sh -u
```

This will:
- Stop the EasyTier service
- Remove all binaries (`easytier-core`, `easytier-cli`)
- Remove all plugin files from OPNsense
- Clean up configuration and PID files
- Restart configd

## Prerequisites

- OPNsense 23.7 or later (FreeBSD-based)
- **For remote install (from your local PC):**
  - SSH access to the OPNsense box (key-based auth recommended)
  - `curl` or `wget` (to download the EasyTier binary)
  - `unzip` (to extract the archive)
  - `git` (to clone this repository)
- **For local install (on the OPNsense box):**
  - Root access (SSH or console)
  - Internet connectivity (to download from GitHub)
  - `git` (or download this repo as ZIP)

## Configuration Guide

### Basic Setup — Join a Network

After installation, configure via the web UI:

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
| **Network Name** | Virtual network identifier; nodes with same name + secret join together | `office-network` |
| **Network Secret** | Shared secret for network authentication | `s3cur3-p@ss` |
| **Hostname** | Optional friendly name for this node | `opnsense-gw` |
| **IPv4 Address** | Static virtual IP in CIDR notation | `10.144.144.1/24` |
| **Use DHCP** | Auto-assign virtual IP from EasyTier DHCP | Checked |
| **Default Protocol** | Default transport protocol | `udp`, `tcp`, `ws`, `wss` |
| **Listeners** | Addresses this node listens on (comma-separated) | `udp://0.0.0.0:11010, tcp://0.0.0.0:11011` |
| **Peer Nodes** | Remote peers to connect to (comma-separated) | `udp://1.2.3.4:11010, tcp://example.com:11010` |
| **Proxy Networks** | Subnets to expose to the VPN (CIDR, comma-separated) | `192.168.1.0/24, 10.0.0.0/16` |
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
   easytier-core --version
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

2. Clear the UI cache: **System → Firmware → Status** → click "Audit now"

3. Verify file permissions:
   ```bash
   ls -la /usr/local/opnsense/mvc/app/controllers/OPNsense/EasyTier/
   ls -la /usr/local/opnsense/mvc/app/models/OPNsense/EasyTier/
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
| `/usr/local/bin/easytier-cli` | EasyTier CLI management tool |
| `/usr/local/etc/easytier.conf` | Generated configuration file |
| `/usr/local/etc/rc.d/easytier` | Service control script |
| `/var/run/easytier.pid` | PID file |
| `/usr/local/opnsense/scripts/OPNsense/EasyTier/reconfigure.sh` | Reconfigure handler |

## Project Structure

```
easytier_opnsense_plugin/
├── install.sh                        # Local automated installer/uninstaller
├── remote-install.sh                 # Remote SSH installer (run from local PC)
├── README.md
├── LICENSE
└── net/easytier/
    ├── Makefile                      # OPNsense plugin metadata
    ├── pkg-descr/pkg-descr          # Package description
    ├── pkg-plist                    # Package file list
    └── src/
        ├── etc/rc.d/easytier        # FreeBSD service script
        └── opnsense/
            ├── mvc/app/
            │   ├── controllers/OPNsense/EasyTier/
            │   │   ├── Api/
            │   │   │   ├── GeneralController.php
            │   │   │   └── ServiceController.php
            │   │   ├── GeneralController.php
            │   │   └── forms/general.xml
            │   ├── models/OPNsense/EasyTier/
            │   │   ├── ACL/ACL.xml
            │   │   ├── EasyTier.php
            │   │   ├── EasyTier.xml
            │   │   └── Menu/Menu.xml
            │   └── views/OPNsense/EasyTier/
            │       └── general.volt
            ├── scripts/OPNsense/EasyTier/
            │   └── reconfigure.sh
            └── service/
                ├── conf/actions.d/actions_easytier.conf
                └── templates/OPNsense/EasyTier/
                    ├── +TARGETS
                    └── easytier.conf
```

## License

This project is licensed under the BSD 2-Clause License. See [LICENSE](LICENSE) for details.

## Links

- [EasyTier Official Website](https://easytier.rs)
- [EasyTier GitHub](https://github.com/EasyTier/EasyTier)
- [EasyTier Releases (Download)](https://github.com/EasyTier/EasyTier/releases)
- [OPNsense Plugin Development Guide](https://docs.opnsense.org/development/examples/helloworld.html)
