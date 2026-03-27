#!/usr/bin/env bash
# Copyright © 2026 Sthenos Security. All rights reserved.
#
# REACHABLE — Detonation Host Setup Script
#
# Sets up a Linux machine as a remote Firecracker detonation host for
# supply chain malware analysis. Run this on a dedicated VM or bare-metal
# server (Ubuntu 22.04+ / Amazon Linux 2023+ recommended).
#
# What this script does:
#   1. Installs Firecracker + jailer (if not present)
#   2. Creates a restricted "detonation" system user
#   3. Generates an Ed25519 SSH keypair for CI runner authentication
#   4. Configures sshd ForceCommand (no shell access — only detonation handler)
#   5. Installs REACHABLE CLI (the handler ships inside the wheel)
#   6. Creates a minimal Firecracker rootfs snapshot
#   7. Prints the private key for you to copy to your CI runner
#
# The detection logic (batch→bisect, .pth scanning, YARA rules, event
# classification) is NOT in this script — it ships inside the reachable
# wheel and is invoked via `reachctl detonation-host serve`.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/detonation/setup-detonation-host.sh | sudo bash
#   # — or —
#   sudo bash setup-detonation-host.sh
#
# Requirements:
#   - Linux x86_64 with KVM support (/dev/kvm must exist)
#   - Root access (sudo)
#   - Python 3.11+ (for reachable wheel)
#   - Internet access (to download Firecracker binary + REACHABLE wheel)
#   - ~2GB disk for rootfs snapshot
#
# After setup, configure your CI runner:
#   reachctl sandbox --remote <this-host-ip>
#
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
FIRECRACKER_VERSION="${FIRECRACKER_VERSION:-1.6.0}"
DETONATION_USER="detonation"
DETONATION_HOME="/opt/reachable/detonation"
HANDLER_BIN="/opt/reachable/bin/detonation-handler"
SSH_KEY_DIR="/opt/reachable/detonation/.ssh"
REACHABLE_DIR="/opt/reachable"
ROOTFS_SIZE_MB="${ROOTFS_SIZE_MB:-512}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

# ─── Preflight Checks ────────────────────────────────────────
preflight() {
    info "Running preflight checks..."

    # Must be root
    [[ $EUID -eq 0 ]] || die "This script must be run as root (sudo)."

    # Must be Linux x86_64
    [[ "$(uname -s)" == "Linux" ]] || die "This script only supports Linux."
    [[ "$(uname -m)" == "x86_64" ]] || die "Firecracker requires x86_64. Got: $(uname -m)"

    # KVM support
    if [[ ! -e /dev/kvm ]]; then
        die "KVM not available. Ensure:\n  1. Running on bare-metal or nested-virt-enabled VM\n  2. CPU supports VT-x/AMD-V\n  3. kvm kernel module is loaded: modprobe kvm kvm_intel"
    fi

    # Check KVM access
    if [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; then
        warn "/dev/kvm exists but not readable/writable. Fixing permissions..."
        chmod 666 /dev/kvm
    fi

    # Python 3.11+ required for REACHABLE
    if ! command -v python3 &>/dev/null; then
        die "Python 3 not found. Install Python 3.11+: apt-get install python3 python3-pip python3-venv"
    fi
    local py_version
    py_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local py_major py_minor
    py_major=$(echo "$py_version" | cut -d. -f1)
    py_minor=$(echo "$py_version" | cut -d. -f2)
    if [[ "$py_major" -lt 3 ]] || [[ "$py_major" -eq 3 && "$py_minor" -lt 11 ]]; then
        die "Python ${py_version} found but 3.11+ required. Install: apt-get install python3.12"
    fi
    ok "Python ${py_version} found"

    ok "Preflight checks passed"
}

# ─── Install Firecracker ─────────────────────────────────────
install_firecracker() {
    if command -v firecracker &>/dev/null; then
        local current_version
        current_version=$(firecracker --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
        ok "Firecracker already installed: v${current_version}"
        return 0
    fi

    info "Installing Firecracker v${FIRECRACKER_VERSION}..."

    local arch="x86_64"
    local release_url="https://github.com/firecracker-microvm/firecracker/releases/download/v${FIRECRACKER_VERSION}"
    local tarball="firecracker-v${FIRECRACKER_VERSION}-${arch}.tgz"

    cd /tmp
    curl -fsSL "${release_url}/${tarball}" -o "${tarball}"
    tar -xzf "${tarball}"

    local bin_dir="release-v${FIRECRACKER_VERSION}-${arch}"
    cp "${bin_dir}/firecracker-v${FIRECRACKER_VERSION}-${arch}" /usr/local/bin/firecracker
    cp "${bin_dir}/jailer-v${FIRECRACKER_VERSION}-${arch}" /usr/local/bin/jailer
    chmod +x /usr/local/bin/firecracker /usr/local/bin/jailer

    rm -rf "${tarball}" "${bin_dir}"

    ok "Firecracker v${FIRECRACKER_VERSION} installed"
}

# ─── Create Detonation User ──────────────────────────────────
create_detonation_user() {
    info "Setting up detonation user and directories..."

    mkdir -p "${REACHABLE_DIR}/bin"
    mkdir -p "${DETONATION_HOME}"
    mkdir -p "${DETONATION_HOME}/rootfs"
    mkdir -p "${DETONATION_HOME}/snapshots"
    mkdir -p "${DETONATION_HOME}/jobs"
    mkdir -p "${DETONATION_HOME}/logs"
    mkdir -p "${SSH_KEY_DIR}"

    if ! id "${DETONATION_USER}" &>/dev/null; then
        useradd \
            --system \
            --home-dir "${DETONATION_HOME}" \
            --shell /usr/sbin/nologin \
            --no-create-home \
            --groups kvm \
            "${DETONATION_USER}"
        ok "Created system user: ${DETONATION_USER}"
    else
        # Ensure kvm group membership
        usermod -aG kvm "${DETONATION_USER}" 2>/dev/null || true
        ok "User ${DETONATION_USER} already exists"
    fi

    chown -R "${DETONATION_USER}:${DETONATION_USER}" "${DETONATION_HOME}"
    ok "Directories created under ${DETONATION_HOME}"
}

# ─── Generate SSH Keypair ────────────────────────────────────
generate_ssh_keys() {
    local key_path="${SSH_KEY_DIR}/detonation_ed25519"

    if [[ -f "${key_path}" ]]; then
        warn "SSH keypair already exists at ${key_path}"
        warn "To regenerate: rm ${key_path} ${key_path}.pub && re-run this script"
    else
        info "Generating Ed25519 SSH keypair..."
        ssh-keygen -t ed25519 \
            -f "${key_path}" \
            -N "" \
            -C "reachable-detonation@$(hostname)" \
            -q

        ok "SSH keypair generated"
    fi

    # Set up authorized_keys
    cat "${key_path}.pub" > "${SSH_KEY_DIR}/authorized_keys"
    chmod 700 "${SSH_KEY_DIR}"
    chmod 600 "${SSH_KEY_DIR}/authorized_keys"
    chmod 600 "${key_path}"
    chown -R "${DETONATION_USER}:${DETONATION_USER}" "${SSH_KEY_DIR}"

    ok "Public key installed in authorized_keys"
}

# ─── Configure SSHD ForceCommand ─────────────────────────────
configure_sshd() {
    info "Configuring SSH restricted access..."

    local sshd_config="/etc/ssh/sshd_config"
    local match_block="Match User ${DETONATION_USER}"

    # Check if already configured
    if grep -q "^${match_block}" "${sshd_config}" 2>/dev/null; then
        ok "SSH ForceCommand already configured for ${DETONATION_USER}"
        return 0
    fi

    # Append restricted match block
    # ForceCommand calls reachctl from the REACHABLE wheel — all detection
    # logic ships in the wheel, not in this script.
    cat >> "${sshd_config}" <<SSHD

# ─── REACHABLE Detonation Host (managed by setup-detonation-host.sh) ───
${match_block}
    ForceCommand ${HANDLER_BIN}
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
    AllowAgentForwarding no
    PermitOpen none
    AuthorizedKeysFile ${SSH_KEY_DIR}/authorized_keys
# ─── END REACHABLE ─────────────────────────────────────────────────────
SSHD

    # Validate config before restarting
    if sshd -t 2>/dev/null; then
        systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
        ok "SSHD configured and reloaded"
    else
        err "SSHD config validation failed! Reverting..."
        sed -i '/# ─── REACHABLE Detonation Host/,/# ─── END REACHABLE/d' "${sshd_config}"
        die "SSHD configuration failed. Check ${sshd_config} manually."
    fi
}

# ─── Install REACHABLE CLI ────────────────────────────────────
#
# The detonation handler is NOT a standalone script — it ships inside
# the reachable wheel as `reachctl detonation-host serve`. This ensures:
#   - Detection logic stays private (compiled in the wheel)
#   - Handler updates when the wheel updates (no stale scripts)
#   - YARA rules, severity model, batch→bisect all come from the wheel
#
install_reachable() {
    info "Installing REACHABLE CLI (detonation handler ships inside)..."

    # Create a venv for the detonation host
    local venv_dir="${REACHABLE_DIR}/venv"

    if [[ -d "${venv_dir}" ]] && "${venv_dir}/bin/reachctl" --version &>/dev/null 2>&1; then
        local current_ver
        current_ver=$("${venv_dir}/bin/reachctl" --version 2>/dev/null | head -1 || echo "unknown")
        ok "REACHABLE already installed: ${current_ver}"
    else
        info "  Installing REACHABLE via official installer..."
        # The official installer handles venv creation, version selection,
        # checksum verification, and cosign signature validation.
        # It installs into ~/.reachable/venv by default; we override
        # REACHABLE_HOME so it installs into /opt/reachable instead.
        export REACHABLE_HOME="${REACHABLE_DIR}"
        curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | bash || {
            die "REACHABLE install failed. Check network access and try again."
        }
    fi

    # Create the handler shim that ForceCommand calls.
    # This thin wrapper delegates to reachctl from the wheel.
    cat > "${HANDLER_BIN}" <<'HANDLER_SHIM'
#!/usr/bin/env bash
# REACHABLE Detonation Handler — ForceCommand shim
#
# This script is the ONLY thing that runs when someone SSHs in as the
# "detonation" user. It delegates to `reachctl detonation-host serve`
# which ships inside the REACHABLE wheel.
#
# No detection logic lives here — it's all in the wheel.
# Update the handler by re-running the installer:
#   curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | REACHABLE_HOME=/opt/reachable bash -s -- --update

set -euo pipefail

VENV="/opt/reachable/venv"
REACHCTL="${VENV}/bin/reachctl"

if [[ ! -x "${REACHCTL}" ]]; then
    echo '{"verdict":"ERROR","error":"reachctl not found. Re-run setup-detonation-host.sh or install via install.sh","packages_tested":0}' >&2
    exit 1
fi

# Delegate to the wheel's detonation handler.
# stdin = JSON job payload, stdout = JSON results
exec "${REACHCTL}" detonation-host serve
HANDLER_SHIM

    chmod +x "${HANDLER_BIN}"
    chown root:root "${HANDLER_BIN}"

    ok "Handler shim installed at ${HANDLER_BIN}"
    ok "Detection logic served from: ${venv_dir}/bin/reachctl detonation-host serve"
}

# ─── Create Rootfs Snapshot ──────────────────────────────────
create_rootfs() {
    info "Creating minimal rootfs for detonation sandbox..."

    local snapshot_dir="${DETONATION_HOME}/snapshots/latest"
    mkdir -p "${snapshot_dir}"

    # Check if kernel exists
    if [[ -f "${snapshot_dir}/vmlinux" ]]; then
        ok "Rootfs snapshot already exists at ${snapshot_dir}"
        return 0
    fi

    # Download minimal kernel
    info "  Downloading Firecracker-compatible kernel..."
    local kernel_url="https://github.com/firecracker-microvm/firecracker/releases/download/v${FIRECRACKER_VERSION}/vmlinux-5.10-x86_64.bin"
    curl -fsSL "${kernel_url}" -o "${snapshot_dir}/vmlinux" || {
        warn "Could not download kernel. You'll need to provide one manually."
        warn "Place vmlinux at: ${snapshot_dir}/vmlinux"
    }

    # Create rootfs image (ext4)
    info "  Creating ${ROOTFS_SIZE_MB}MB ext4 rootfs..."
    dd if=/dev/zero of="${snapshot_dir}/rootfs.ext4" bs=1M count="${ROOTFS_SIZE_MB}" status=none
    mkfs.ext4 -q -F "${snapshot_dir}/rootfs.ext4"

    # Mount and populate with debootstrap (Ubuntu minimal)
    local mnt="/tmp/reachable-rootfs-mnt"
    mkdir -p "${mnt}"
    mount -o loop "${snapshot_dir}/rootfs.ext4" "${mnt}"

    if command -v debootstrap &>/dev/null; then
        info "  Running debootstrap (this takes 1-3 minutes)..."
        debootstrap --include=python3,python3-pip,python3-venv,openssh-server,curl,jq,tcpdump \
            jammy "${mnt}" http://archive.ubuntu.com/ubuntu || {
            warn "debootstrap failed. Rootfs will need manual setup."
            umount "${mnt}" 2>/dev/null || true
            return 0
        }

        # Install Node.js in rootfs
        chroot "${mnt}" bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && apt-get install -y nodejs" 2>/dev/null || true

        # Install REACHABLE inside the guest rootfs (for sandbox-agent).
        # Uses the official installer — we override HOME so it installs
        # into /root/.reachable inside the chroot.
        chroot "${mnt}" bash -c "curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | HOME=/root bash" 2>/dev/null || true

        # Generate guest SSH key
        ssh-keygen -t ed25519 -f "${snapshot_dir}/guest_key" -N "" -q
        mkdir -p "${mnt}/root/.ssh"
        cat "${snapshot_dir}/guest_key.pub" > "${mnt}/root/.ssh/authorized_keys"
        chmod 700 "${mnt}/root/.ssh"
        chmod 600 "${mnt}/root/.ssh/authorized_keys"

    else
        warn "debootstrap not found. Install it: apt-get install debootstrap"
        warn "Rootfs is empty — run 'reachctl detonation-host rebuild' after installing debootstrap."
    fi

    umount "${mnt}"
    rmdir "${mnt}" 2>/dev/null || true
    chown -R "${DETONATION_USER}:${DETONATION_USER}" "${snapshot_dir}"

    ok "Rootfs snapshot created at ${snapshot_dir}"
}

# ─── Create Systemd Service ──────────────────────────────────
install_systemd_service() {
    info "Installing systemd service..."

    # The service calls reachctl from the wheel — not a standalone binary.
    cat > /etc/systemd/system/reachable-detonation.service <<SERVICE
[Unit]
Description=REACHABLE Detonation Host Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=${DETONATION_USER}
Group=${DETONATION_USER}
WorkingDirectory=${DETONATION_HOME}
ExecStart=${REACHABLE_DIR}/venv/bin/reachctl detonation-host serve --daemon
Restart=on-failure
RestartSec=10

# Security hardening
NoNewPrivileges=false
ProtectSystem=strict
ReadWritePaths=${DETONATION_HOME} /tmp/firecracker
PrivateTmp=true

# KVM access
SupplementaryGroups=kvm

[Install]
WantedBy=multi-user.target
SERVICE

    systemctl daemon-reload
    ok "Systemd service installed (not started — start with: systemctl start reachable-detonation)"
}

# ─── Print Summary ───────────────────────────────────────────
print_summary() {
    local key_path="${SSH_KEY_DIR}/detonation_ed25519"
    local host_ip
    host_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "<this-host-ip>")

    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  REACHABLE Detonation Host — Setup Complete${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Host:       ${BLUE}${host_ip}${NC}"
    echo -e "  User:       ${DETONATION_USER}"
    echo -e "  Handler:    ${HANDLER_BIN} → reachctl detonation-host serve"
    echo -e "  Snapshots:  ${DETONATION_HOME}/snapshots"
    echo -e "  Jobs:       ${DETONATION_HOME}/jobs"
    echo ""
    echo -e "${YELLOW}─── PRIVATE KEY (copy this to your CI runner) ───${NC}"
    echo ""
    cat "${key_path}"
    echo ""
    echo -e "${YELLOW}─── END PRIVATE KEY ─────────────────────────────${NC}"
    echo ""
    echo -e "  Save the key above to a file, then run on your CI runner:"
    echo ""
    echo -e "    ${BLUE}# Option 1: Interactive setup${NC}"
    echo -e "    reachctl sandbox --remote ${host_ip}"
    echo ""
    echo -e "    ${BLUE}# Option 2: Manual setup${NC}"
    echo -e "    mkdir -p ~/.reachable"
    echo -e "    # Paste private key into ~/.reachable/sandbox_key"
    echo -e "    chmod 600 ~/.reachable/sandbox_key"
    echo -e "    cat >> ~/.reachable/config.toml <<EOF"
    echo -e "    [sandbox]"
    echo -e "    mode = \"remote\""
    echo -e "    transport = \"ssh\""
    echo -e "    ssh_host = \"${host_ip}\""
    echo -e "    ssh_user = \"detonation\""
    echo -e "    ssh_key = \"~/.reachable/sandbox_key\""
    echo -e "    EOF"
    echo ""
    echo -e "    ${BLUE}# Option 3: Environment variables (CI/CD)${NC}"
    echo -e "    export REACHABLE_SANDBOX_SSH=${host_ip}"
    echo -e "    export REACHABLE_SANDBOX_SSH_KEY=/path/to/sandbox_key"
    echo ""
    echo -e "  ${BLUE}Test the connection:${NC}"
    echo -e "    reachctl sandbox --status"
    echo ""
    echo -e "  ${BLUE}Or test directly with SSH:${NC}"
    echo -e "    echo '{\"packages\":[{\"name\":\"requests\",\"ecosystem\":\"pip\"}]}' | \\"
    echo -e "      ssh -i ~/.reachable/sandbox_key detonation@${host_ip}"
    echo ""
    echo -e "${GREEN}  Fingerprint of public key:${NC}"
    ssh-keygen -lf "${key_path}.pub" 2>/dev/null || true
    echo ""
    echo -e "  ${BLUE}Update detection logic:${NC}"
    echo -e "    curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/install.sh | REACHABLE_HOME=${REACHABLE_DIR} sudo bash -s -- --update"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────
main() {
    echo -e "${GREEN}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║   REACHABLE — Detonation Host Setup             ║"
    echo "  ║   Supply Chain Malware Detonation Service        ║"
    echo "  ║   © 2026 Sthenos Security                       ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"

    preflight
    install_firecracker
    create_detonation_user
    generate_ssh_keys
    configure_sshd
    install_reachable       # Installs wheel + handler shim (no detection logic here)
    create_rootfs
    install_systemd_service
    print_summary
}

main "$@"
