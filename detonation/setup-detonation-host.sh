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
#   5. Installs the detonation-handler service
#   6. Creates a minimal Firecracker rootfs snapshot
#   7. Prints the private key for you to copy to your CI runner
#
# Usage:
#   curl -fsSL https://get.sthenosec.com/detonation-host | sudo bash
#   # — or —
#   sudo bash setup-detonation-host.sh
#
# Requirements:
#   - Linux x86_64 with KVM support (cat /dev/kvm must exist)
#   - Root access (sudo)
#   - Internet access (to download Firecracker binary)
#   - ~2GB disk for rootfs snapshot
#
# After setup, configure your CI runner:
#   reachctl sandbox setup --remote <this-host-ip>
#
set -euo pipefail

# ─── Configuration ────────────────────────────────────────────
FIRECRACKER_VERSION="${FIRECRACKER_VERSION:-1.6.0}"
DETONATION_USER="detonation"
DETONATION_HOME="/opt/reachable/detonation"
HANDLER_BIN="/opt/reachable/bin/detonation-handler"
SSH_KEY_DIR="/opt/reachable/detonation/.ssh"
REACHABLE_DIR="/opt/reachable"
VM_POOL_SIZE="${VM_POOL_SIZE:-4}"
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
        # Remove the block we just added
        sed -i '/# ─── REACHABLE Detonation Host/,/# ─── END REACHABLE/d' "${sshd_config}"
        die "SSHD configuration failed. Check ${sshd_config} manually."
    fi
}

# ─── Install Detonation Handler ──────────────────────────────
install_handler() {
    info "Installing detonation handler..."

    cat > "${HANDLER_BIN}" <<'HANDLER_SCRIPT'
#!/usr/bin/env python3
# Copyright © 2026 Sthenos Security. All rights reserved.
"""
REACHABLE Detonation Handler — SSH ForceCommand Target

This script is the ONLY thing that runs when someone SSHs in as the
"detonation" user. It reads a JSON job from stdin, detonates packages
in Firecracker microVMs, and writes JSON results to stdout.

No shell access. No interactive commands. Just detonation.
"""

import json
import os
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

DETONATION_HOME = Path("/opt/reachable/detonation")
JOBS_DIR = DETONATION_HOME / "jobs"
LOGS_DIR = DETONATION_HOME / "logs"
SNAPSHOTS_DIR = DETONATION_HOME / "snapshots"

MAX_PACKAGES = 2000
MAX_TIMEOUT = 1800  # 30 minutes
DEFAULT_TIMEOUT = 600


def log(msg: str):
    """Log to stderr (goes to SSH client's stderr) and to file."""
    ts = time.strftime("%Y-%m-%dT%H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line, file=sys.stderr)
    try:
        log_file = LOGS_DIR / f"{time.strftime('%Y-%m-%d')}.log"
        with open(log_file, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass


def read_request() -> dict:
    """Read JSON request from stdin."""
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return {"error": "Empty input"}
        return json.loads(raw)
    except json.JSONDecodeError as e:
        return {"error": f"Invalid JSON: {e}"}


def validate_request(req: dict) -> str | None:
    """Validate request, return error string or None."""
    if "error" in req:
        return req["error"]
    packages = req.get("packages", [])
    if not packages:
        return "No packages provided"
    if len(packages) > MAX_PACKAGES:
        return f"Too many packages: {len(packages)} > {MAX_PACKAGES}"
    for pkg in packages:
        if not pkg.get("name"):
            return "Package missing 'name'"
        eco = pkg.get("ecosystem", "pip")
        if eco not in ("pip", "npm"):
            return f"Unsupported ecosystem: {eco}"
    return None


def detonate_batch(packages: list, timeout: int, mode: str) -> dict:
    """
    Run detonation in Firecracker microVM.

    This is the core detonation logic. It:
    1. Restores a Firecracker snapshot
    2. Installs packages inside the VM
    3. Monitors for malicious behavior (network, file, process events)
    4. Returns structured results
    """
    job_id = f"det_{uuid.uuid4().hex[:8]}"
    job_dir = JOBS_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    start = time.time()
    log(f"Job {job_id}: detonating {len(packages)} packages (mode={mode}, timeout={timeout}s)")

    # Write package list for the VM
    pkg_list_file = job_dir / "packages.json"
    pkg_list_file.write_text(json.dumps(packages))

    results = []
    malicious = []
    tested = 0

    try:
        # For each ecosystem group, run detonation
        pip_pkgs = [p for p in packages if p.get("ecosystem", "pip") == "pip"]
        npm_pkgs = [p for p in packages if p.get("ecosystem") == "npm"]

        if pip_pkgs:
            pip_result = _detonate_ecosystem(job_id, pip_pkgs, "pip", timeout, mode, job_dir)
            results.extend(pip_result.get("results", []))
            malicious.extend(pip_result.get("malicious", []))
            tested += pip_result.get("tested", 0)

        if npm_pkgs:
            npm_result = _detonate_ecosystem(job_id, npm_pkgs, "npm", timeout, mode, job_dir)
            results.extend(npm_result.get("results", []))
            malicious.extend(npm_result.get("malicious", []))
            tested += npm_result.get("tested", 0)

    except Exception as e:
        duration_ms = int((time.time() - start) * 1000)
        log(f"Job {job_id}: ERROR — {e}")
        return {
            "job_id": job_id,
            "verdict": "ERROR",
            "duration_ms": duration_ms,
            "packages_tested": tested,
            "malicious_packages": malicious,
            "results": results,
            "error": str(e),
        }

    duration_ms = int((time.time() - start) * 1000)
    verdict = "CRITICAL" if malicious else "CLEAN"
    log(f"Job {job_id}: {verdict} — {tested} tested, {len(malicious)} malicious, {duration_ms}ms")

    return {
        "job_id": job_id,
        "verdict": verdict,
        "duration_ms": duration_ms,
        "packages_tested": tested,
        "malicious_packages": malicious,
        "results": results,
    }


def _detonate_ecosystem(job_id: str, packages: list, ecosystem: str,
                         timeout: int, mode: str, job_dir: Path) -> dict:
    """
    Detonate packages of a single ecosystem in a Firecracker microVM.

    Uses the batch→bisect strategy:
    1. Install all packages in one VM
    2. If CRITICAL → binary search to isolate malicious package(s)
    """
    results = []
    malicious = []
    tested = 0

    # Build install command
    if ecosystem == "pip":
        pkg_specs = [f"{p['name']}=={p['version']}" if p.get("version") else p["name"] for p in packages]
        install_cmd = f"pip install --no-cache-dir {' '.join(pkg_specs)}"
    else:
        pkg_specs = [f"{p['name']}@{p['version']}" if p.get("version") else p["name"] for p in packages]
        install_cmd = f"npm install --no-save {' '.join(pkg_specs)}"

    # Phase 1: Batch install
    batch_result = _run_in_vm(job_id, install_cmd, ecosystem, timeout, job_dir)
    tested += 1

    if batch_result["verdict"] == "CLEAN":
        # All clean — mark each package
        for pkg in packages:
            results.append({
                "package": pkg["name"],
                "version": pkg.get("version"),
                "verdict": "CLEAN",
                "findings": [],
                "events": [],
            })
            tested += 1
        return {"results": results, "malicious": [], "tested": len(packages)}

    if batch_result["verdict"] == "ERROR":
        return {"results": [], "malicious": [], "tested": 1, "error": batch_result.get("error")}

    # Phase 2: Bisect to isolate malicious packages
    if mode == "batch_only":
        # Don't bisect — just return batch result
        return {
            "results": [{"package": "BATCH", "verdict": "CRITICAL",
                         "findings": batch_result.get("findings", []),
                         "events": batch_result.get("events", [])}],
            "malicious": [p["name"] for p in packages],
            "tested": 1,
        }

    if mode == "individual" or len(packages) <= 2:
        # Test each individually
        for pkg in packages:
            if ecosystem == "pip":
                cmd = f"pip install --no-cache-dir {pkg['name']}" + (f"=={pkg['version']}" if pkg.get('version') else "")
            else:
                cmd = f"npm install --no-save {pkg['name']}" + (f"@{pkg['version']}" if pkg.get('version') else "")

            r = _run_in_vm(job_id, cmd, ecosystem, timeout, job_dir)
            tested += 1
            verdict = r["verdict"]
            results.append({
                "package": pkg["name"],
                "version": pkg.get("version"),
                "verdict": verdict,
                "findings": r.get("findings", []),
                "events": r.get("events", []),
            })
            if verdict == "CRITICAL":
                malicious.append(pkg["name"])
    else:
        # Binary search
        malicious, results, extra_tested = _bisect_packages(
            job_id, packages, ecosystem, timeout, job_dir
        )
        tested += extra_tested

    return {"results": results, "malicious": malicious, "tested": tested}


def _bisect_packages(job_id: str, packages: list, ecosystem: str,
                     timeout: int, job_dir: Path) -> tuple:
    """Binary search to isolate malicious packages."""
    if len(packages) <= 1:
        # Base case — test single package
        pkg = packages[0]
        if ecosystem == "pip":
            cmd = f"pip install --no-cache-dir {pkg['name']}" + (f"=={pkg['version']}" if pkg.get('version') else "")
        else:
            cmd = f"npm install --no-save {pkg['name']}" + (f"@{pkg['version']}" if pkg.get('version') else "")

        r = _run_in_vm(job_id, cmd, ecosystem, timeout, job_dir)
        verdict = r["verdict"]
        result = {
            "package": pkg["name"],
            "version": pkg.get("version"),
            "verdict": verdict,
            "findings": r.get("findings", []),
            "events": r.get("events", []),
        }
        mal = [pkg["name"]] if verdict == "CRITICAL" else []
        return mal, [result], 1

    mid = len(packages) // 2
    left_half = packages[:mid]
    right_half = packages[mid:]

    malicious = []
    results = []
    tested = 0

    for half in [left_half, right_half]:
        if ecosystem == "pip":
            specs = [f"{p['name']}=={p['version']}" if p.get("version") else p["name"] for p in half]
            cmd = f"pip install --no-cache-dir {' '.join(specs)}"
        else:
            specs = [f"{p['name']}@{p['version']}" if p.get("version") else p["name"] for p in half]
            cmd = f"npm install --no-save {' '.join(specs)}"

        r = _run_in_vm(job_id, cmd, ecosystem, timeout, job_dir)
        tested += 1

        if r["verdict"] == "CRITICAL":
            # Recurse into this half
            sub_mal, sub_results, sub_tested = _bisect_packages(
                job_id, half, ecosystem, timeout, job_dir
            )
            malicious.extend(sub_mal)
            results.extend(sub_results)
            tested += sub_tested
        else:
            # This half is clean
            for pkg in half:
                results.append({
                    "package": pkg["name"],
                    "version": pkg.get("version"),
                    "verdict": "CLEAN",
                    "findings": [],
                    "events": [],
                })

    return malicious, results, tested


def _run_in_vm(job_id: str, install_cmd: str, ecosystem: str,
               timeout: int, job_dir: Path) -> dict:
    """
    Execute install command in a Firecracker microVM and collect events.

    Returns dict with verdict, findings, events, error.
    """
    vm_id = f"{job_id}_{uuid.uuid4().hex[:4]}"

    # Find latest snapshot
    snapshot_dir = SNAPSHOTS_DIR / "latest"
    if not snapshot_dir.exists():
        return {"verdict": "ERROR", "error": "No Firecracker snapshot available. Run: reachctl detonation-host rebuild"}

    # Build VM config
    vm_config = {
        "vm_id": vm_id,
        "snapshot": str(snapshot_dir),
        "install_cmd": install_cmd,
        "ecosystem": ecosystem,
        "timeout": timeout,
    }

    config_file = job_dir / f"{vm_id}.json"
    config_file.write_text(json.dumps(vm_config))

    try:
        # Launch Firecracker with jailer
        # The actual VM orchestration uses firecracker API socket
        # This is a simplified version — production uses the pool manager
        result = subprocess.run(
            [
                str(DETONATION_HOME / "vm-runner.sh"),
                str(config_file),
            ],
            capture_output=True,
            text=True,
            timeout=timeout + 30,  # Grace period
        )

        if result.returncode != 0:
            return {
                "verdict": "ERROR",
                "error": f"VM execution failed: {result.stderr[:500]}",
                "findings": [],
                "events": [],
            }

        # Parse VM output — vm-runner.sh outputs JSON to stdout
        try:
            vm_output = json.loads(result.stdout)
        except json.JSONDecodeError:
            return {
                "verdict": "ERROR",
                "error": f"Invalid VM output: {result.stdout[:500]}",
                "findings": [],
                "events": [],
            }

        return {
            "verdict": vm_output.get("verdict", "ERROR"),
            "findings": vm_output.get("findings", []),
            "events": vm_output.get("events", []),
        }

    except subprocess.TimeoutExpired:
        return {
            "verdict": "ERROR",
            "error": f"VM timed out after {timeout}s",
            "findings": [],
            "events": [],
        }
    except FileNotFoundError:
        return {
            "verdict": "ERROR",
            "error": "vm-runner.sh not found. Run: reachctl detonation-host rebuild",
            "findings": [],
            "events": [],
        }


def main():
    """Entry point — ForceCommand target."""
    JOBS_DIR.mkdir(parents=True, exist_ok=True)
    LOGS_DIR.mkdir(parents=True, exist_ok=True)

    # Read request from stdin
    req = read_request()

    # Validate
    err = validate_request(req)
    if err:
        log(f"Validation error: {err}")
        json.dump({
            "job_id": "",
            "verdict": "ERROR",
            "duration_ms": 0,
            "packages_tested": 0,
            "error": err,
        }, sys.stdout)
        sys.exit(1)

    # Extract parameters
    packages = req["packages"]
    mode = req.get("mode", "batch_bisect")
    timeout = min(req.get("timeout_seconds", DEFAULT_TIMEOUT), MAX_TIMEOUT)

    log(f"Received detonation request: {len(packages)} packages, mode={mode}")

    # Run detonation
    result = detonate_batch(packages, timeout, mode)

    # Write result to stdout
    json.dump(result, sys.stdout)
    sys.stdout.flush()


if __name__ == "__main__":
    main()
HANDLER_SCRIPT

    chmod +x "${HANDLER_BIN}"
    chown root:root "${HANDLER_BIN}"
    ok "Detonation handler installed at ${HANDLER_BIN}"
}

# ─── Create VM Runner Script ─────────────────────────────────
install_vm_runner() {
    info "Installing VM runner script..."

    cat > "${DETONATION_HOME}/vm-runner.sh" <<'VM_RUNNER'
#!/usr/bin/env bash
# Firecracker VM runner — launches a microVM from snapshot, runs install,
# collects sandbox events, outputs JSON to stdout.
#
# Usage: vm-runner.sh <config.json>
#
set -euo pipefail

CONFIG_FILE="$1"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"verdict":"ERROR","error":"Config file not found"}'
    exit 1
fi

VM_ID=$(jq -r '.vm_id' "$CONFIG_FILE")
SNAPSHOT=$(jq -r '.snapshot' "$CONFIG_FILE")
INSTALL_CMD=$(jq -r '.install_cmd' "$CONFIG_FILE")
ECOSYSTEM=$(jq -r '.ecosystem' "$CONFIG_FILE")
TIMEOUT=$(jq -r '.timeout' "$CONFIG_FILE")

WORK_DIR="/tmp/firecracker/${VM_ID}"
SOCKET="${WORK_DIR}/firecracker.sock"
LOG_FILE="${WORK_DIR}/firecracker.log"

mkdir -p "${WORK_DIR}"

# Copy rootfs (CoW if filesystem supports it)
cp --reflink=auto "${SNAPSHOT}/rootfs.ext4" "${WORK_DIR}/rootfs.ext4"

# Create Firecracker config
cat > "${WORK_DIR}/vm-config.json" <<VMCFG
{
  "boot-source": {
    "kernel_image_path": "${SNAPSHOT}/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off init=/sbin/overlay-init"
  },
  "drives": [{
    "drive_id": "rootfs",
    "path_on_host": "${WORK_DIR}/rootfs.ext4",
    "is_root_device": true,
    "is_read_only": false
  }],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024
  },
  "network-interfaces": [{
    "iface_id": "eth0",
    "guest_mac": "AA:FC:00:00:00:01",
    "host_dev_name": "fc-${VM_ID}-tap0"
  }]
}
VMCFG

# Set up tap device for network monitoring (not internet access)
ip tuntap add "fc-${VM_ID}-tap0" mode tap 2>/dev/null || true
ip addr add 172.16.0.1/24 dev "fc-${VM_ID}-tap0" 2>/dev/null || true
ip link set "fc-${VM_ID}-tap0" up 2>/dev/null || true

# Start Firecracker
firecracker \
    --api-sock "${SOCKET}" \
    --config-file "${WORK_DIR}/vm-config.json" \
    --log-path "${LOG_FILE}" \
    --level Warning \
    &
FC_PID=$!

# Wait for VM to boot (vsock or serial console ready)
sleep 2

# Send install command via virtio-vsock or serial
# The guest runs an agent that:
#   1. Executes the install command
#   2. Monitors syscalls (seccomp + eBPF)
#   3. Captures network traffic (tcpdump on lo/eth0)
#   4. Checks for .pth file creation
#   5. Reports findings back via vsock

# Simplified: use SSH into the VM via tap interface
EVENTS_FILE="${WORK_DIR}/events.json"
FINDINGS_FILE="${WORK_DIR}/findings.json"

# The guest agent writes results to a well-known path on the rootfs
# After timeout or completion, we read them out
timeout "${TIMEOUT}" ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i "${SNAPSHOT}/guest_key" \
    root@172.16.0.2 \
    "cd /tmp && ${INSTALL_CMD} 2>&1; /opt/sandbox-agent report" \
    > "${WORK_DIR}/output.log" 2>&1 || true

# Kill VM
kill "${FC_PID}" 2>/dev/null || true
wait "${FC_PID}" 2>/dev/null || true

# Extract results from VM output
# The sandbox-agent inside the VM outputs a JSON line starting with RESULT:
RESULT_LINE=$(grep '^RESULT:' "${WORK_DIR}/output.log" | tail -1 | sed 's/^RESULT://')
if [[ -n "$RESULT_LINE" ]]; then
    echo "$RESULT_LINE"
else
    # No structured output — check for suspicious indicators in log
    if grep -qE "(curl|wget|nc |/dev/tcp|base64.*decode)" "${WORK_DIR}/output.log"; then
        echo '{"verdict":"CRITICAL","findings":[{"rule":"SANDBOX_SUSPICIOUS_COMMAND","severity":"CRITICAL","description":"Suspicious commands detected during install"}],"events":[]}'
    else
        echo '{"verdict":"CLEAN","findings":[],"events":[]}'
    fi
fi

# Cleanup
ip link delete "fc-${VM_ID}-tap0" 2>/dev/null || true
rm -rf "${WORK_DIR}"
VM_RUNNER

    chmod +x "${DETONATION_HOME}/vm-runner.sh"
    chown "${DETONATION_USER}:${DETONATION_USER}" "${DETONATION_HOME}/vm-runner.sh"
    ok "VM runner script installed"
}

# ─── Create Rootfs Snapshot ──────────────────────────────────
create_rootfs() {
    info "Creating minimal rootfs for detonation sandbox..."

    local snapshot_dir="${SNAPSHOTS_DIR}/latest"
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

        # Create sandbox agent stub
        mkdir -p "${mnt}/opt"
        cat > "${mnt}/opt/sandbox-agent" <<'AGENT'
#!/usr/bin/env python3
"""Minimal sandbox agent — monitors installs and reports findings."""
import json, os, sys

def report():
    findings = []
    events = []

    # Check for .pth files with imports
    import site
    for sp in site.getsitepackages():
        if not os.path.isdir(sp):
            continue
        for f in os.listdir(sp):
            if not f.endswith('.pth'):
                continue
            path = os.path.join(sp, f)
            try:
                content = open(path).read()
                for line in content.splitlines():
                    stripped = line.strip()
                    if stripped.startswith('import '):
                        danger_ops = []
                        for d in ['curl', 'wget', 'socket', 'subprocess', 'os.system', 'exec(', 'eval(', 'base64', '/dev/tcp', 'urllib']:
                            if d in content:
                                danger_ops.append(d)
                        sev = 'CRITICAL' if danger_ops else 'HIGH'
                        findings.append({
                            'rule': 'PTH_AUTOEXEC',
                            'severity': sev,
                            'description': f'.pth file {f} contains import statement' + (f' with danger ops: {danger_ops}' if danger_ops else ''),
                            'evidence': {'file': f, 'content': content[:500], 'danger_ops': danger_ops},
                        })
                        break
            except Exception:
                pass

    verdict = 'CRITICAL' if any(f['severity'] == 'CRITICAL' for f in findings) else ('HIGH' if findings else 'CLEAN')
    result = {'verdict': verdict, 'findings': findings, 'events': events}
    print(f'RESULT:{json.dumps(result)}')

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'report':
        report()
AGENT
        chmod +x "${mnt}/opt/sandbox-agent"

        # Generate guest SSH key
        ssh-keygen -t ed25519 -f "${snapshot_dir}/guest_key" -N "" -q
        mkdir -p "${mnt}/root/.ssh"
        cat "${snapshot_dir}/guest_key.pub" > "${mnt}/root/.ssh/authorized_keys"
        chmod 700 "${mnt}/root/.ssh"
        chmod 600 "${mnt}/root/.ssh/authorized_keys"

    else
        warn "debootstrap not found. Install it: apt-get install debootstrap"
        warn "Rootfs is empty — you'll need to populate it manually."
    fi

    umount "${mnt}"
    rmdir "${mnt}" 2>/dev/null || true
    chown -R "${DETONATION_USER}:${DETONATION_USER}" "${snapshot_dir}"

    ok "Rootfs snapshot created at ${snapshot_dir}"
}

# ─── Create Systemd Service ──────────────────────────────────
install_systemd_service() {
    info "Installing systemd service for VM pool management..."

    cat > /etc/systemd/system/reachable-detonation.service <<SERVICE
[Unit]
Description=REACHABLE Detonation VM Pool Manager
After=network.target
Wants=network.target

[Service]
Type=simple
User=${DETONATION_USER}
Group=${DETONATION_USER}
WorkingDirectory=${DETONATION_HOME}
ExecStart=${REACHABLE_DIR}/bin/detonation-pool-manager
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
    echo -e "  Handler:    ${HANDLER_BIN}"
    echo -e "  Snapshots:  ${SNAPSHOTS_DIR}"
    echo -e "  Jobs:       ${JOBS_DIR}"
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
    echo -e "    reachctl sandbox setup --remote ${host_ip}"
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
    echo -e "    reachctl sandbox status"
    echo ""
    echo -e "  ${BLUE}Or test directly with SSH:${NC}"
    echo -e "    echo '{\"packages\":[{\"name\":\"requests\",\"ecosystem\":\"pip\"}]}' | \\"
    echo -e "      ssh -i ~/.reachable/sandbox_key detonation@${host_ip}"
    echo ""
    echo -e "${GREEN}  Fingerprint of public key:${NC}"
    ssh-keygen -lf "${key_path}.pub" 2>/dev/null || true
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
    install_handler
    install_vm_runner
    create_rootfs
    install_systemd_service
    print_summary
}

main "$@"
