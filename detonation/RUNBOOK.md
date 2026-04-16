# REACHABLE — Remote Detonation Host Runbook

Operational guide for deploying and managing a remote Firecracker detonation
host for supply chain malware analysis.

---

## Architecture Overview

```
┌──────────────────┐         SSH (ForceCommand)        ┌─────────────────────────┐
│  CI Runner or    │ ─────────────────────────────────► │  Detonation Host        │
│  Dev Machine     │   Ed25519 keypair                  │  (bare-metal / VM)      │
│                  │   StrictHostKeyChecking=yes         │                         │
│  reachctl scan   │                                    │  ┌───────────────────┐  │
│  --sandbox-mode  │   JSON stdin → JSON stdout         │  │ detonation-handler│  │
│    remote        │ ◄───────────────────────────────── │  │ (ForceCommand)    │  │
└──────────────────┘                                    │  └────────┬──────────┘  │
                                                        │           │             │
                                                        │  ┌────────▼──────────┐  │
                                                        │  │ Firecracker Pool  │  │
                                                        │  │ (microVMs)        │  │
                                                        │  │                   │  │
                                                        │  │ vm-1  vm-2  vm-3  │  │
                                                        │  └───────────────────┘  │
                                                        └─────────────────────────┘
```

The detonation host runs Firecracker microVMs with KVM isolation. Packages
are installed inside ephemeral VMs that are destroyed after each job. The SSH
connection uses `ForceCommand` — the `detonation` user has no shell access;
only the detonation handler binary runs.

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| OS | Ubuntu 22.04+, Amazon Linux 2023+, Debian 12+ |
| Architecture | x86_64 with KVM support |
| KVM | `/dev/kvm` must exist and be readable |
| RAM | 8 GB minimum (16 GB recommended for 4-VM pool) |
| Disk | 10 GB free (rootfs snapshots + job data) |
| Network | SSH inbound from CI runners (port 22) |
| Root | Required for initial setup only |

To verify KVM:

```bash
ls -la /dev/kvm          # must exist
cat /proc/cpuinfo | grep -E 'vmx|svm'   # must show VT-x or AMD-V
```

Cloud VM compatibility: AWS `.metal` or `.bare-metal` instances, GCP with
nested virtualization enabled, Azure Dv3/Ev3 with nested virt. Standard VMs
without nested virt will NOT work.

---

## Initial Setup

### Option A: Automated (recommended)

Run the setup script on the detonation host:

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/detonation/setup-detonation-host.sh | sudo bash
```

Or download and review first:

```bash
curl -fsSL https://raw.githubusercontent.com/sthenos-security/reach-dist/main/detonation/setup-detonation-host.sh -o setup.sh
less setup.sh
sudo bash setup.sh
```

The script will print a private key at the end. Copy it to your CI runner.

### Option B: Remote provisioning via reachctl

From your CI runner or dev machine:

```bash
# 1. Register the host (saves SSH config locally)
reachctl sandbox --remote <detonation-host-ip>

# 2. Push and run setup script over SSH (requires root SSH access)
reachctl sandbox --provision

# 3. Verify
reachctl sandbox --status
```

### Option C: Manual setup

See the setup script source for each step. In summary:

1. Install Firecracker and jailer to `/usr/local/bin/`
2. Create system user `detonation` with `/usr/sbin/nologin` shell, add to `kvm` group
3. Generate Ed25519 keypair at `/opt/reachable/detonation/.ssh/`
4. Configure sshd `Match User detonation` with `ForceCommand /opt/reachable/bin/detonation-handler`
5. Install the detonation-handler Python script at `/opt/reachable/bin/`
6. Create rootfs snapshot with debootstrap (Python + Node.js + sandbox-agent)

---

## CI Runner Configuration

### Environment variables (CI/CD)

```bash
# Required
export REACHABLE_SANDBOX_SSH=<detonation-host-ip>
export REACHABLE_SANDBOX_SSH_KEY=/path/to/sandbox_key

# Optional
export REACHABLE_SANDBOX_SSH_USER=detonation   # default
export REACHABLE_SANDBOX_MODE=remote           # or auto
```

### Config file (~/.reachable/config.toml)

```toml
[sandbox]
mode = "remote"
transport = "ssh"
ssh_host = "10.0.1.50"
ssh_user = "detonation"
ssh_key = "~/.reachable/sandbox_key"
known_hosts = "~/.reachable/sandbox_known_hosts"
machine_id = "a1b2c3d4e5f6..."
```

Created automatically by `reachctl sandbox --remote <host>`.

### GitHub Actions

Store as secrets: `REACHABLE_SANDBOX_HOST`, `REACHABLE_SANDBOX_KEY`.

```yaml
- name: Configure Remote Sandbox
  run: |
    mkdir -p ~/.reachable
    echo "${{ secrets.REACHABLE_SANDBOX_KEY }}" > ~/.reachable/sandbox_key
    chmod 600 ~/.reachable/sandbox_key

- name: Scan with Detonation
  env:
    REACHABLE_SANDBOX_SSH: ${{ secrets.REACHABLE_SANDBOX_HOST }}
    REACHABLE_SANDBOX_SSH_KEY: ~/.reachable/sandbox_key
  run: reachctl scan . --sandbox-mode remote --ci --fail-on high
```

See `detonation/github-actions-detonation.yml` for the full workflow.

### GitLab CI

Store as CI/CD variables: `REACHABLE_SANDBOX_HOST`, `REACHABLE_SANDBOX_KEY`.

```yaml
reachable-detonation:
  stage: test
  before_script:
    - mkdir -p ~/.reachable
    - echo "$REACHABLE_SANDBOX_KEY" > ~/.reachable/sandbox_key
    - chmod 600 ~/.reachable/sandbox_key
  script:
    - reachctl scan . --sandbox-mode remote --ci --fail-on high
  variables:
    REACHABLE_SANDBOX_SSH: $REACHABLE_SANDBOX_HOST
    REACHABLE_SANDBOX_SSH_KEY: ~/.reachable/sandbox_key
```

See `detonation/gitlab-ci-detonation.yml` for the full pipeline.

---

## Operations

### Check status

```bash
reachctl sandbox --status
```

Shows: connection status, host key verification, machine-id verification,
handler reachability.

### Rebuild VM snapshots

After OS patches or rootfs changes:

```bash
reachctl sandbox --rebuild
```

Or on the host directly:

```bash
sudo systemctl restart reachable-detonation
```

### View logs

```bash
# On the detonation host
tail -f /opt/reachable/detonation/logs/$(date +%Y-%m-%d).log

# Or via SSH (as root)
ssh root@<host> "tail -100 /opt/reachable/detonation/logs/$(date +%Y-%m-%d).log"
```

### Clear job data

```bash
# Via reachctl
reachctl sandbox --teardown

# Or on the host
sudo rm -rf /opt/reachable/detonation/jobs/*
sudo rm -rf /tmp/firecracker/*
```

### Rotate SSH keys

```bash
# On the detonation host
sudo ssh-keygen -t ed25519 -f /opt/reachable/detonation/.ssh/detonation_ed25519 -N "" -q
sudo cat /opt/reachable/detonation/.ssh/detonation_ed25519.pub > /opt/reachable/detonation/.ssh/authorized_keys
sudo chown -R detonation:detonation /opt/reachable/detonation/.ssh

# Then re-register from CI runner
reachctl sandbox --remote <host>
```

Update the private key in your CI secrets after rotation.

---

## Security Model

### SSH transport

| Layer | Protection |
|-------|-----------|
| Authentication | Ed25519 keypair (no passwords) |
| Authorization | `ForceCommand` — detonation handler is the ONLY thing that runs |
| Host verification | `StrictHostKeyChecking=yes` with pinned known_hosts |
| Machine identity | `/etc/machine-id` verified on each connection |
| Network | No TCP forwarding, no X11, no tunneling, no agent forwarding |
| Privileges | `detonation` user is a system account with `nologin` shell |

### Firecracker VM isolation

| Layer | Protection |
|-------|-----------|
| Hypervisor | KVM hardware virtualization (not containers) |
| Blast radius | Each job runs in a fresh VM, destroyed after completion |
| Network | Guest has tap interface for monitoring only — no internet access |
| Escape cost | 3+ exploit chain required: guest kernel → Firecracker → jailer → host |
| Snapshot restore | Fresh rootfs copy per VM — <20ms from CoW snapshot |

### What the VM monitors

| Signal | Detection method |
|--------|-----------------|
| Credential theft | Honeypot files: `~/.aws/credentials`, `~/.ssh/id_rsa`, `~/.docker/config.json` |
| Network exfil | tcpdump on tap interface, all outbound blocked |
| .pth auto-exec | Post-install scan of site-packages for `.pth` files with import statements |
| Persistence | inotify on crontab, bashrc, systemd unit directories |
| Obfuscation | Pattern match for base64+decode, marshal, exec/eval/compile chains |

---

## Troubleshooting

### "Connection refused" on SSH

```bash
# Verify SSH is running on the host
ssh root@<host> "systemctl status sshd"

# Check firewall
ssh root@<host> "ufw status"         # Ubuntu
ssh root@<host> "iptables -L -n"     # general
```

### "Permission denied" on SSH

```bash
# Verify the public key is installed
ssh root@<host> "cat /opt/reachable/detonation/.ssh/authorized_keys"

# Verify the private key matches
ssh-keygen -lf ~/.reachable/sandbox_key
ssh root@<host> "ssh-keygen -lf /opt/reachable/detonation/.ssh/detonation_ed25519.pub"
# Fingerprints must match
```

### "HOST KEY MISMATCH" error

This is the anti-MITM protection. The host's SSH key has changed since setup.

If expected (host rebuilt, keys regenerated):

```bash
reachctl sandbox --remote <host>    # re-register with new host key
```

If unexpected: investigate before re-registering. Someone may be intercepting
the connection.

### "No Firecracker snapshot available"

```bash
# On the host — rebuild rootfs
sudo bash /tmp/setup-detonation-host.sh   # or re-run setup

# Or rebuild remotely
reachctl sandbox --rebuild
```

### KVM not available

```bash
# Check CPU virtualization support
grep -E 'vmx|svm' /proc/cpuinfo

# Load KVM module
sudo modprobe kvm kvm_intel   # Intel
sudo modprobe kvm kvm_amd     # AMD

# Fix /dev/kvm permissions
sudo chmod 666 /dev/kvm
```

If running inside a cloud VM, enable nested virtualization:
- AWS: use `.metal` instance types
- GCP: `--enable-nested-virtualization` on instance creation
- Azure: Dv3/Ev3 series support nested virt

### Detonation timeout

Default timeout is 600 seconds (10 minutes). For large package sets:

```bash
# Increase via environment variable
export REACHABLE_SANDBOX_TIMEOUT=1200   # 20 minutes
```

Or in the JSON payload to the handler:

```json
{"packages": [...], "timeout_seconds": 1200}
```

### VM pool exhaustion

If all VMs are busy and jobs queue up:

```bash
# Check active jobs
ssh root@<host> "ls /opt/reachable/detonation/jobs/"

# Kill stale VMs
ssh root@<host> "pkill -f firecracker"

# Or reboot the pool
reachctl sandbox --rebuild
```

---

## Teardown

### Soft teardown (stop service, keep Firecracker installed)

```bash
reachctl sandbox --teardown
```

### Full removal

```bash
# On the host
sudo systemctl stop reachable-detonation
sudo systemctl disable reachable-detonation
sudo rm -rf /opt/reachable
sudo userdel detonation
sudo rm /etc/systemd/system/reachable-detonation.service

# Remove sshd config block
sudo sed -i '/# ─── REACHABLE Detonation Host/,/# ─── END REACHABLE/d' /etc/ssh/sshd_config
sudo systemctl reload sshd

# Optionally remove Firecracker
sudo rm /usr/local/bin/firecracker /usr/local/bin/jailer
```

### Remove local config (CI runner)

```bash
rm -f ~/.reachable/sandbox_key
rm -f ~/.reachable/sandbox_known_hosts
# Remove [sandbox] section from ~/.reachable/config.toml
```

---

## Directory Layout (Detonation Host)

```
/opt/reachable/
├── bin/
│   └── detonation-handler      # ForceCommand target (Python)
└── detonation/
    ├── .ssh/
    │   ├── detonation_ed25519   # Private key (stays on host)
    │   ├── detonation_ed25519.pub
    │   └── authorized_keys      # Public keys of CI runners
    ├── rootfs/                  # Firecracker rootfs build area
    ├── snapshots/
    │   └── latest/
    │       ├── vmlinux          # Firecracker-compatible kernel
    │       ├── rootfs.ext4      # Base rootfs image
    │       └── guest_key        # SSH key for guest access
    ├── jobs/                    # Per-job working directories
    │   └── det_a1b2c3d4/
    │       ├── packages.json
    │       └── vm_*.json
    ├── logs/                    # Daily log files
    │   └── 2026-03-27.log
    └── vm-runner.sh             # Firecracker VM launcher
```

---

## CLI Quick Reference

| Command | What it does |
|---------|-------------|
| `reachctl sandbox --remote <host>` | Register detonation host (save SSH config + host identity) |
| `reachctl sandbox --provision` | Remotely install Firecracker on the host via SSH |
| `reachctl sandbox --status` | Check connection, verify host identity |
| `reachctl sandbox --rebuild` | Rebuild VM snapshots on remote host |
| `reachctl sandbox --teardown` | Stop service, clear job data |
| `reachctl scan /repo --sandbox-mode remote` | Scan with remote detonation |
| `reachctl scan /repo --sandbox-mode auto` | Auto-detect (macOS=local, Linux=remote) |
| `reachctl scan /repo --sandbox-mode local` | Force local Docker/Colima sandbox |
| `reachctl scan /repo --sandbox-mode off` | Disable sandbox entirely |

---

© 2026 Sthenos Security. All rights reserved.
