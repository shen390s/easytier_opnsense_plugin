#!/bin/sh
#
# EasyTier OPNsense Plugin - Automated Installer
#
# Usage:
#   ./install.sh [OPTIONS]
#
# Options:
#   -v VERSION    EasyTier version to install (e.g., 2.6.4)
#   -f FBSD_VER   FreeBSD version for binary selection (default: auto-detected)
#   -a ARCH       Architecture (default: x86_64)
#   -u            Uninstall the plugin
#   -h            Show this help message
#
# Examples:
#   ./install.sh -v 2.6.4
#   ./install.sh -v 2.6.4 -f 13.2 -a x86_64
#   ./install.sh -u
#

set -e

# Defaults
EASYTIER_VERSION=""
EASYTIER_ARCH="x86_64"
EASYTIER_FBSD_VERSION=""
UNINSTALL=0
PREFIX="/usr/local"
GITHUB_BASE="https://github.com/EasyTier/EasyTier/releases/download"

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
    echo "EasyTier OPNsense Plugin Installer"
    echo ""
    echo "Usage:"
    echo "  $0 -v VERSION [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v VERSION    EasyTier version to install (required, e.g., 2.6.4)"
    echo "  -f FBSD_VER   FreeBSD version for binary (default: auto-detected from system)"
    echo "  -a ARCH       Architecture (default: x86_64)"
    echo "  -u            Uninstall the plugin"
    echo "  -h            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -v 2.6.4"
    echo "  $0 -v 2.6.4 -f 14.2"
    echo "  $0 -v 2.6.4 -f 13.2 -a x86_64"
    echo "  $0 -u"
    exit 0
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root"
    fi
}

check_dependencies() {
    for cmd in fetch unzip; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Required command '$cmd' not found. Please install it first."
        fi
    done
}

detect_freebsd_version() {
    # Detect the FreeBSD major.minor version (e.g., 13.2, 14.1)
    local fbsd_ver=""
    if command -v freebsd-version >/dev/null 2>&1; then
        fbsd_ver=$(freebsd-version -u 2>/dev/null | cut -d'-' -f1 | cut -d'.' -f1,2)
    fi
    if [ -z "${fbsd_ver}" ]; then
        fbsd_ver=$(uname -r | cut -d'-' -f1 | cut -d'.' -f1,2)
    fi
    echo "${fbsd_ver}"
}

download_easytier() {
    local version="$1"
    local arch="$2"
    local fbsd_ver="$3"
    local tmpdir=$(mktemp -d)
    local downloaded=0

    # Generate candidate FreeBSD versions (exact match first, then older compatible)
    # FreeBSD binaries built on older versions generally run on newer versions
    local candidates=""
    if [ -n "${fbsd_ver}" ]; then
        local major=$(echo "${fbsd_ver}" | cut -d'.' -f1)
        local minor=$(echo "${fbsd_ver}" | cut -d'.' -f2)

        # Same major, from detected minor down to 0
        local m=${minor}
        while [ ${m} -ge 0 ]; do
            candidates="${candidates} ${major}.${m}"
            m=$((m - 1))
        done

        # Previous major versions (try common ones down to 13)
        local prev_major=$((major - 1))
        while [ ${prev_major} -ge 13 ]; do
            local pm=4
            while [ ${pm} -ge 0 ]; do
                candidates="${candidates} ${prev_major}.${pm}"
                pm=$((pm - 1))
            done
            prev_major=$((prev_major - 1))
        done
    else
        # Could not detect version — try all common FreeBSD versions
        candidates="14.4 14.3 14.2 14.1 14.0 13.4 13.3 13.2 13.1 13.0"
    fi

    info "Downloading EasyTier v${version} for FreeBSD/${arch}..."
    if [ -n "${fbsd_ver}" ]; then
        info "Detected FreeBSD: ${fbsd_ver} — trying compatible binary versions..."
    else
        info "FreeBSD version unknown — trying all known versions..."
    fi

    for candidate in ${candidates}; do
        local filename="easytier-freebsd-${candidate}-${arch}-v${version}.zip"
        local url="${GITHUB_BASE}/v${version}/${filename}"

        info "  Trying: ${filename}..."
        if fetch -o "${tmpdir}/${filename}" "${url}" 2>/dev/null; then
            info "  Found compatible binary: FreeBSD ${candidate}"
            downloaded=1
            break
        fi
    done

    if [ ${downloaded} -eq 0 ]; then
        rm -rf "${tmpdir}"
        error "No compatible EasyTier binary found for FreeBSD ${fbsd_ver}/${arch} v${version}. Tried versions: $(echo ${candidates} | tr ' ' ', ')"
    fi

    info "Extracting archive..."
    if ! unzip -o "${tmpdir}/${filename}" -d "${tmpdir}" >/dev/null 2>&1; then
        rm -rf "${tmpdir}"
        error "Failed to extract archive. The download may be corrupted."
    fi

    # Find and install binaries (search entire tmpdir — archive extracts to a subdirectory
    # like easytier-freebsd-13.2-x86_64/ whose name varies by version)
    info "Installing EasyTier binaries..."
    for binary in easytier-core easytier-cli; do
        local binpath=$(find "${tmpdir}" -name "${binary}" -type f | head -1)
        if [ -n "${binpath}" ]; then
            install -m 0755 "${binpath}" "${PREFIX}/bin/${binary}"
            info "  Installed ${PREFIX}/bin/${binary}"
        else
            warn "  Binary '${binary}' not found in archive"
        fi
    done

    rm -rf "${tmpdir}"
    info "EasyTier binaries installed successfully."
}

install_plugin() {
    local srcdir="$(cd "$(dirname "$0")" && pwd)/net/easytier/src"

    if [ ! -d "${srcdir}" ]; then
        error "Plugin source directory not found at ${srcdir}"
    fi

    info "Installing OPNsense plugin files..."

    # rc.d service script
    install -m 0755 "${srcdir}/etc/rc.d/easytier" "${PREFIX}/etc/rc.d/easytier"
    info "  Installed rc.d service script"

    # MVC Controllers
    mkdir -p "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api"
    mkdir -p "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/forms"
    install -m 0644 "${srcdir}/opnsense/mvc/app/controllers/OPNsense/EasyTier/IndexController.php" \
        "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/IndexController.php"
    install -m 0644 "${srcdir}/opnsense/mvc/app/controllers/OPNsense/EasyTier/GeneralController.php" \
        "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/GeneralController.php"
    install -m 0644 "${srcdir}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/GeneralController.php" \
        "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/GeneralController.php"
    install -m 0644 "${srcdir}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/ServiceController.php" \
        "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/Api/ServiceController.php"
    install -m 0644 "${srcdir}/opnsense/mvc/app/controllers/OPNsense/EasyTier/forms/general.xml" \
        "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier/forms/general.xml"
    info "  Installed MVC controllers"

    # MVC Models
    mkdir -p "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/ACL"
    mkdir -p "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/Menu"
    install -m 0644 "${srcdir}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.php" \
        "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.php"
    install -m 0644 "${srcdir}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.xml" \
        "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/EasyTier.xml"
    install -m 0644 "${srcdir}/opnsense/mvc/app/models/OPNsense/EasyTier/ACL/ACL.xml" \
        "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/ACL/ACL.xml"
    install -m 0644 "${srcdir}/opnsense/mvc/app/models/OPNsense/EasyTier/Menu/Menu.xml" \
        "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier/Menu/Menu.xml"
    info "  Installed MVC models"

    # MVC Views
    mkdir -p "${PREFIX}/opnsense/mvc/app/views/OPNsense/EasyTier"
    install -m 0644 "${srcdir}/opnsense/mvc/app/views/OPNsense/EasyTier/general.volt" \
        "${PREFIX}/opnsense/mvc/app/views/OPNsense/EasyTier/general.volt"
    info "  Installed MVC views"

    # Scripts
    mkdir -p "${PREFIX}/opnsense/scripts/OPNsense/EasyTier"
    install -m 0755 "${srcdir}/opnsense/scripts/OPNsense/EasyTier/reconfigure.sh" \
        "${PREFIX}/opnsense/scripts/OPNsense/EasyTier/reconfigure.sh"
    info "  Installed scripts"

    # Service configuration (configd actions)
    mkdir -p "${PREFIX}/opnsense/service/conf/actions.d"
    install -m 0644 "${srcdir}/opnsense/service/conf/actions.d/actions_easytier.conf" \
        "${PREFIX}/opnsense/service/conf/actions.d/actions_easytier.conf"
    info "  Installed configd actions"

    # Service templates
    mkdir -p "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier"
    install -m 0644 "${srcdir}/opnsense/service/templates/OPNsense/EasyTier/+TARGETS" \
        "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier/+TARGETS"
    install -m 0644 "${srcdir}/opnsense/service/templates/OPNsense/EasyTier/easytier.conf" \
        "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier/easytier.conf"
    info "  Installed service templates"

    info "Plugin files installed successfully."
}

restart_services() {
    info "Restarting configd to pick up new actions..."
    if service configd restart >/dev/null 2>&1; then
        info "  configd restarted successfully"
    else
        warn "  Failed to restart configd (may need manual restart)"
    fi
}

uninstall() {
    info "Uninstalling EasyTier OPNsense plugin..."

    # Stop service if running
    if [ -f "${PREFIX}/etc/rc.d/easytier" ]; then
        info "Stopping EasyTier service..."
        ${PREFIX}/etc/rc.d/easytier stop 2>/dev/null || true
    fi

    # Remove plugin files
    info "Removing plugin files..."
    rm -rf "${PREFIX}/opnsense/mvc/app/controllers/OPNsense/EasyTier"
    rm -rf "${PREFIX}/opnsense/mvc/app/models/OPNsense/EasyTier"
    rm -rf "${PREFIX}/opnsense/mvc/app/views/OPNsense/EasyTier"
    rm -rf "${PREFIX}/opnsense/scripts/OPNsense/EasyTier"
    rm -f  "${PREFIX}/opnsense/service/conf/actions.d/actions_easytier.conf"
    rm -rf "${PREFIX}/opnsense/service/templates/OPNsense/EasyTier"
    rm -f  "${PREFIX}/etc/rc.d/easytier"
    rm -f  "${PREFIX}/etc/easytier.conf"

    # Remove binaries
    info "Removing EasyTier binaries..."
    rm -f "${PREFIX}/bin/easytier-core"
    rm -f "${PREFIX}/bin/easytier-cli"

    # Remove PID file
    rm -f /var/run/easytier.pid

    # Disable service
    sysrc -x easytier_enable 2>/dev/null || true

    # Restart configd
    restart_services

    info "EasyTier plugin uninstalled successfully."
}

# Parse arguments
while getopts "v:f:a:uh" opt; do
    case ${opt} in
        v) EASYTIER_VERSION="${OPTARG}" ;;
        f) EASYTIER_FBSD_VERSION="${OPTARG}" ;;
        a) EASYTIER_ARCH="${OPTARG}" ;;
        u) UNINSTALL=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Main
check_root

if [ ${UNINSTALL} -eq 1 ]; then
    uninstall
    exit 0
fi

if [ -z "${EASYTIER_VERSION}" ]; then
    error "EasyTier version is required. Use -v VERSION (e.g., -v 2.6.4)"
fi

# Auto-detect FreeBSD version if not specified
if [ -z "${EASYTIER_FBSD_VERSION}" ]; then
    EASYTIER_FBSD_VERSION=$(detect_freebsd_version)
    if [ -z "${EASYTIER_FBSD_VERSION}" ]; then
        warn "Could not detect FreeBSD version. Will try all known versions."
    fi
fi

check_dependencies

info "=== EasyTier OPNsense Plugin Installer ==="
info "EasyTier Version: ${EASYTIER_VERSION}"
info "FreeBSD Version:  ${EASYTIER_FBSD_VERSION}"
info "Architecture:     ${EASYTIER_ARCH}"
info ""

download_easytier "${EASYTIER_VERSION}" "${EASYTIER_ARCH}" "${EASYTIER_FBSD_VERSION}"
install_plugin
restart_services

info ""
info "=== Installation Complete ==="
info ""
info "Next steps:"
info "  1. Navigate to VPN -> EasyTier in the OPNsense web UI"
info "  2. Configure your network settings"
info "  3. Enable the service and click Save"
info ""
info "Installed binaries:"
info "  ${PREFIX}/bin/easytier-core"
info "  ${PREFIX}/bin/easytier-cli"
info ""
info "To verify: easytier-core --help"
