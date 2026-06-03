#!/bin/sh
#
# EasyTier OPNsense Plugin - Remote Installer
#
# Run this from your LOCAL machine to install the EasyTier plugin
# on a remote OPNsense box via SSH.
#
# Prerequisites:
#   - SSH access to the OPNsense box (key-based auth recommended)
#   - git (to clone this repo locally)
#   - curl or wget (to download the EasyTier binary locally)
#
# Usage:
#   ./remote-install.sh -H HOST -v VERSION [OPTIONS]
#
# Examples:
#   ./remote-install.sh -H root@192.168.1.1 -v 2.6.4
#   ./remote-install.sh -H root@opnsense.local -v 2.6.4 -f 14.2 -p 22
#   ./remote-install.sh -H root@192.168.1.1 -u
#

set -e

# Defaults
REMOTE_HOST=""
REMOTE_PORT="22"
REMOTE_USER="root"
EASYTIER_VERSION=""
EASYTIER_ARCH="x86_64"
EASYTIER_FBSD_VERSION=""
UNINSTALL=0
SSH_OPTS=""
GITHUB_BASE="https://github.com/EasyTier/EasyTier/releases/download"
PREFIX="/usr/local"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
    exit 1
}

usage() {
    echo "EasyTier OPNsense Plugin - Remote Installer"
    echo ""
    echo "Install the EasyTier plugin on a remote OPNsense box via SSH."
    echo ""
    echo "Usage:"
    echo "  $0 -H HOST -v VERSION [OPTIONS]"
    echo ""
    echo "Required:"
    echo "  -H HOST       Remote host (e.g., root@192.168.1.1 or root@opnsense.local)"
    echo "  -v VERSION    EasyTier version to install (e.g., 2.6.4)"
    echo ""
    echo "Options:"
    echo "  -p PORT       SSH port (default: 22)"
    echo "  -f FBSD_VER   FreeBSD version for binary (default: auto-detected from remote)"
    echo "  -a ARCH       Architecture (default: x86_64)"
    echo "  -i KEY        SSH identity file (private key path)"
    echo "  -u            Uninstall the plugin from remote host"
    echo "  -h            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -H root@192.168.1.1 -v 2.6.4"
    echo "  $0 -H root@opnsense.local -v 2.6.4 -p 2222"
    echo "  $0 -H root@192.168.1.1 -v 2.6.4 -f 14.2 -i ~/.ssh/opnsense_key"
    echo "  $0 -H root@192.168.1.1 -u"
    exit 0
}

# Run a command on the remote host
remote_exec() {
    ssh ${SSH_OPTS} -p "${REMOTE_PORT}" "${REMOTE_HOST}" "$@"
}

# Copy a file to the remote host
remote_copy() {
    scp ${SSH_OPTS} -P "${REMOTE_PORT}" "$1" "${REMOTE_HOST}:$2"
}

# Copy a directory to the remote host
remote_copy_dir() {
    scp ${SSH_OPTS} -P "${REMOTE_PORT}" -r "$1" "${REMOTE_HOST}:$2"
}

# Setup SSH connection multiplexing to avoid repeated password prompts
setup_ssh_multiplexing() {
    SSH_CONTROL_PATH="/tmp/easytier_ssh_$$_%h_%p_%r"
    SSH_OPTS="${SSH_OPTS} -o ControlPath=${SSH_CONTROL_PATH}"

    info "Establishing SSH connection to ${REMOTE_HOST}..."
    # Note: do NOT redirect stdout/stderr here so password prompt is visible
    if ! ssh ${SSH_OPTS} -p "${REMOTE_PORT}" -o ControlMaster=yes -o ControlPersist=300 \
        "${REMOTE_HOST}" "true"; then
        error "Failed to establish SSH connection to ${REMOTE_HOST}"
    fi
    info "  SSH connection established (multiplexed)."
}

# Cleanup SSH multiplexed connection
cleanup_ssh_multiplexing() {
    if [ -n "${SSH_CONTROL_PATH}" ]; then
        ssh -o ControlPath="${SSH_CONTROL_PATH}" -p "${REMOTE_PORT}" -O exit "${REMOTE_HOST}" 2>/dev/null || true
    fi
}

check_local_dependencies() {
    for cmd in ssh scp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Required command '$cmd' not found."
        fi
    done

    # Need at least one download tool
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1 && ! command -v fetch >/dev/null 2>&1; then
        error "Need curl, wget, or fetch to download EasyTier binary."
    fi
}

check_remote_connectivity() {
    # Connection already verified by setup_ssh_multiplexing
    # This is a quick sanity check using the multiplexed connection
    if ! remote_exec "true" 2>/dev/null; then
        error "SSH multiplexed connection lost to ${REMOTE_HOST}"
    fi
}

detect_remote_freebsd_version() {
    local raw_ver=""
    local fbsd_ver=""

    # Run the simplest possible command on remote — no pipes, no subshells
    # Try freebsd-version first
    raw_ver=$(remote_exec "freebsd-version -u" 2>/dev/null) || true

    # If that failed, try uname -r
    if [ -z "${raw_ver}" ]; then
        raw_ver=$(remote_exec "uname -r" 2>/dev/null) || true
    fi

    # Process locally: "14.3-RELEASE-p8" -> "14.3"
    if [ -n "${raw_ver}" ]; then
        # Remove control chars, take part before first '-', then major.minor
        fbsd_ver=$(printf '%s' "${raw_ver}" | tr -d '[:cntrl:]' | tr -d ' ' | cut -d'-' -f1 | cut -d'.' -f1,2)
    fi

    echo "${fbsd_ver}"
}

download_binary_locally() {
    local version="$1"
    local arch="$2"
    local fbsd_ver="$3"
    local filename="easytier-freebsd-${fbsd_ver}-${arch}-v${version}.zip"
    local url="${GITHUB_BASE}/v${version}/${filename}"
    local tmpdir=$(mktemp -d)

    info "Downloading EasyTier v${version} for FreeBSD ${fbsd_ver}/${arch}..."
    info "URL: ${url}"

    if command -v curl >/dev/null 2>&1; then
        if ! curl -fSL -o "${tmpdir}/${filename}" "${url}"; then
            rm -rf "${tmpdir}"
            error "Failed to download. Check version number and network."
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -q -O "${tmpdir}/${filename}" "${url}"; then
            rm -rf "${tmpdir}"
            error "Failed to download. Check version number and network."
        fi
    elif command -v fetch >/dev/null 2>&1; then
        if ! fetch -o "${tmpdir}/${filename}" "${url}"; then
            rm -rf "${tmpdir}"
            error "Failed to download. Check version number and network."
        fi
    fi

    info "Extracting archive locally..."
    if command -v unzip >/dev/null 2>&1; then
        unzip -o "${tmpdir}/${filename}" -d "${tmpdir}/easytier" >/dev/null 2>&1
    else
        # Try with python as fallback
        python3 -c "
import zipfile, sys
with zipfile.ZipFile('${tmpdir}/${filename}', 'r') as z:
    z.extractall('${tmpdir}/easytier')
" 2>/dev/null || error "Cannot extract ZIP. Install 'unzip' or 'python3'."
    fi

    # Return the temp directory path
    echo "${tmpdir}"
}

install_remote() {
    local tmpdir="$1"
    local srcdir="$(cd "$(dirname "$0")" && pwd)/net/easytier/src"

    if [ ! -d "${srcdir}" ]; then
        error "Plugin source directory not found at ${srcdir}. Run from the repository root."
    fi

    # Upload binaries
    info "Uploading EasyTier binaries to remote host..."
    for binary in easytier-core easytier-cli; do
        local binpath=$(find "${tmpdir}/easytier" -name "${binary}" -type f | head -1)
        if [ -n "${binpath}" ]; then
            remote_copy "${binpath}" "/tmp/${binary}"
            remote_exec "install -m 0755 /tmp/${binary} ${PREFIX}/bin/${binary} && rm /tmp/${binary}"
            info "  Installed ${PREFIX}/bin/${binary}"
        else
            warn "  Binary '${binary}' not found in archive"
        fi
    done

    # Upload plugin files
    info "Uploading OPNsense plugin files..."

    # Create a temporary staging directory on remote
    remote_exec "rm -rf /tmp/easytier_plugin && mkdir -p /tmp/easytier_plugin"

    # Copy the entire src directory to remote
    remote_copy_dir "${srcdir}" "/tmp/easytier_plugin/src"

    # Install on remote using a heredoc script
    remote_exec "sh -s" <<'REMOTE_SCRIPT'
set -e
PREFIX="/usr/local"
SRCDIR="/tmp/easytier_plugin/src"

# rc.d service script
install -m 0755 "${SRCDIR}/etc/rc.d/easytier" "${PREFIX}/etc/rc.d/easytier"

# MVC Controllers
mkdir -p "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api"
mkdir -p "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/forms"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/controllers/OPNsense/EasyTier/GeneralController.php" \
    "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/GeneralController.php"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/GeneralController.php" \
    "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/GeneralController.php"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/ServiceController.php" \
    "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/ServiceController.php"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/controllers/OPNsense/EasyTier/forms/general.xml" \
    "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/forms/general.xml"

# MVC Models
mkdir -p "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/ACL"
mkdir -p "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/Menu"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.php" \
    "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.php"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.xml" \
    "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.xml"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/models/OPNsense/EasyTier/ACL/ACL.xml" \
    "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/ACL/ACL.xml"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/models/OPNsense/EasyTier/Menu/Menu.xml" \
    "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/Menu/Menu.xml"

# MVC Views
mkdir -p "${PREFIX}/opnsense/mvc/app/views/OPNsense/EasyTier"
install -m 0644 "${SRCDIR}/opnsense/mvc/app/views/OPNsense/EasyTier/general.volt" \
    "${PREFIX}/opnsense/mvc/app/views/OPNsense/EasyTier/general.volt"

# Scripts
mkdir -p "${PREFIX}/opnsense/scripts/OPNsense/EasyTier"
install -m 0755 "${SRCDIR}/opnsense/scripts/OPNsense/EasyTier/reconfigure.sh" \
    "${PREFIX}/opnsense/scripts/OPNsense/EasyTier/reconfigure.sh"

# Service configuration (configd actions)
mkdir -p "${PREFIX}/opnsense/service/conf/actions.d"
install -m 0644 "${SRCDIR}/opnsense/service/conf/actions.d/actions_easytier.conf" \
    "${PREFIX}/opnsense/service/conf/actions.d/actions_easytier.conf"

# Service templates
mkdir -p "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier"
install -m 0644 "${SRCDIR}/opnsense/service/templates/OPNsense/EasyTier/+TARGETS" \
    "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier/+TARGETS"
install -m 0644 "${SRCDIR}/opnsense/service/templates/OPNsense/EasyTier/easytier.conf" \
    "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier/easytier.conf"

# Cleanup staging
rm -rf /tmp/easytier_plugin

# Restart configd
service configd restart >/dev/null 2>&1 || true
REMOTE_SCRIPT

    info "  Plugin files installed on remote host."
}

uninstall_remote() {
    info "Uninstalling EasyTier plugin from ${REMOTE_HOST}..."

    remote_exec "sh -s" <<'REMOTE_UNINSTALL'
set -e
PREFIX="/usr/local"

# Stop service
if [ -f "${PREFIX}/etc/rc.d/easytier" ]; then
    ${PREFIX}/etc/rc.d/easytier stop 2>/dev/null || true
fi

# Remove plugin files
rm -rf "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier"
rm -rf "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier"
rm -rf "${PREFIX}/opnsense/mvc/app/views/OPNsense/EasyTier"
rm -rf "${PREFIX}/opnsense/scripts/OPNsense/EasyTier"
rm -f  "${PREFIX}/opnsense/service/conf/actions.d/actions_easytier.conf"
rm -rf "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier"
rm -f  "${PREFIX}/etc/rc.d/easytier"
rm -f  "${PREFIX}/etc/easytier.conf"

# Remove binaries
rm -f "${PREFIX}/bin/easytier-core"
rm -f "${PREFIX}/bin/easytier-cli"

# Remove PID file
rm -f /var/run/easytier.pid

# Disable service
sysrc -x easytier_enable 2>/dev/null || true

# Restart configd
service configd restart >/dev/null 2>&1 || true
REMOTE_UNINSTALL

    info "EasyTier plugin uninstalled from ${REMOTE_HOST}."
}

# Parse arguments
while getopts "H:p:v:f:a:i:uh" opt; do
    case ${opt} in
        H) REMOTE_HOST="${OPTARG}" ;;
        p) REMOTE_PORT="${OPTARG}" ;;
        v) EASYTIER_VERSION="${OPTARG}" ;;
        f) EASYTIER_FBSD_VERSION="${OPTARG}" ;;
        a) EASYTIER_ARCH="${OPTARG}" ;;
        i) SSH_OPTS="${SSH_OPTS} -i ${OPTARG}" ;;
        u) UNINSTALL=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required args
if [ -z "${REMOTE_HOST}" ]; then
    error "Remote host is required. Use -H HOST (e.g., -H root@192.168.1.1)"
fi

# Check local dependencies
check_local_dependencies

# Setup SSH multiplexing (single password prompt for all operations)
setup_ssh_multiplexing
trap cleanup_ssh_multiplexing EXIT

# Check SSH connectivity
check_remote_connectivity

# Handle uninstall
if [ ${UNINSTALL} -eq 1 ]; then
    uninstall_remote
    exit 0
fi

# Validate version
if [ -z "${EASYTIER_VERSION}" ]; then
    error "EasyTier version is required. Use -v VERSION (e.g., -v 2.6.4)"
fi

# Auto-detect FreeBSD version from remote if not specified
if [ -z "${EASYTIER_FBSD_VERSION}" ]; then
    info "Detecting FreeBSD version on remote host..."
    EASYTIER_FBSD_VERSION=$(detect_remote_freebsd_version)
    # Validate we got a reasonable version string (e.g., "13.2", "14.1")
    if [ -z "${EASYTIER_FBSD_VERSION}" ] || ! echo "${EASYTIER_FBSD_VERSION}" | grep -qE '^[0-9]+\.[0-9]+$'; then
        error "Could not detect FreeBSD version on remote host (got: '${EASYTIER_FBSD_VERSION}'). Please specify manually with -f (e.g., -f 13.2 or -f 14.2)"
    fi
    info "  Detected FreeBSD ${EASYTIER_FBSD_VERSION}"
fi

info "=== EasyTier Remote Installer ==="
info "Remote Host:      ${REMOTE_HOST} (port ${REMOTE_PORT})"
info "EasyTier Version: ${EASYTIER_VERSION}"
info "FreeBSD Version:  ${EASYTIER_FBSD_VERSION}"
info "Architecture:     ${EASYTIER_ARCH}"
info ""

# Download binary locally
TMPDIR=$(download_binary_locally "${EASYTIER_VERSION}" "${EASYTIER_ARCH}" "${EASYTIER_FBSD_VERSION}")

# Install on remote
install_remote "${TMPDIR}"

# Cleanup local temp
rm -rf "${TMPDIR}"

info ""
info "=== Remote Installation Complete ==="
info ""
info "Next steps:"
info "  1. Open https://${REMOTE_HOST##*@}/ui/easytier/general in your browser"
info "  2. Configure your network settings"
info "  3. Enable the service and click Save"
info ""
info "To verify remotely:"
info "  ssh ${REMOTE_HOST} -p ${REMOTE_PORT} 'easytier-core --help'"
