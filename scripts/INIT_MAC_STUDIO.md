# init_mac_studio.sh — Documentation

> Mac Studio Server Initialization Script for OpenClaw deployment

> **Warning:** This script makes high-impact system changes, including auto-login, SSH, firewall/pf configuration, fail2ban setup, sleep/hibernate changes, and remote-access tool installation. Review it carefully before running it on any machine.

---

## Overview

`init_mac_studio.sh` is a single Bash script that fully stages a fresh Mac Studio as a headless/semi-headless server in one run. It handles system configuration, installs all core dependencies, hardens the machine for remote access, and configures AI inference tooling — with zero reboots required during execution.

**Target OS:** macOS Tahoe 26.4+
**Target hardware:** Mac Studio (Apple Silicon or Intel)
**Runtime:** ~20–30 minutes (most of that is Python 3.14 compilation)

---

## Prerequisites

Before running the script, confirm the following:

| Requirement | Status needed |
|-------------|---------------|
| macOS fully up to date | ✅ |
| FileVault | **Off** |
| Logged in as the server's primary user | ✅ |
| Internet connection | ✅ |
| Xcode Command Line Tools | Not required — script installs them |

---

## How to Run

### Step 1 — Get the script onto the Mac Studio

Clone this repo or copy the script directly:

```bash
# Option A: clone this repo
git clone https://github.com/chiefguppi/openclaw_shared.git ~/openclaw_shared
cd ~/openclaw_shared/scripts

# Option B: copy the file manually via AirDrop, USB, or scp
```

### Step 2 — Make it executable

```bash
chmod +x init_mac_studio.sh
```

### Step 3 — Run with sudo

```bash
sudo bash init_mac_studio.sh
```

> **Important:** Use `sudo bash init_mac_studio.sh`, not `./init_mac_studio.sh` or `sudo ./init_mac_studio.sh`. The script detects your real username from `$SUDO_USER` and runs user-space tools (Homebrew, pyenv, Python) as that user — not as root.

### Step 4 — Respond to prompts

The script has two interactive pauses:

1. **Password prompt** — Enter the account password for the user you're logged in as. This is used to configure auto-login via `sysadminctl`. It is never stored or echoed.

2. **Xcode CLT dialog** (first run only) — A macOS system dialog will appear to install Xcode Command Line Tools. Click **Install**, wait for it to complete, then press **Enter** in the terminal to continue.

Everything else runs unattended.

### Step 5 — Reboot once when complete

One setting requires a reboot to take effect:

- **GPU wired memory limit** (`iogpu.wired_limit_mb`) — written to `/etc/sysctl.conf`, applied on next boot

```bash
sudo reboot
```

### Step 6 — Complete manual steps

After the reboot, three steps remain that cannot be automated:

**Tailscale authentication:**
1. Open the Tailscale app from the menu bar
2. Log in to your tailnet
3. In Tailscale Settings: enable **Launch at login**
4. Set **VPN On Demand** → **Always Run**

**SSH key setup** (run from your client machine, not the Mac Studio):
```bash
ssh-copy-id <username>@<mac-studio-ip>
```
Then verify passwordless login:
```bash
ssh <username>@<mac-studio-ip>
```

**RustDesk relay** *(optional)*:
Configure the client to point at your self-hosted relay/broker server if desired.

---

## What the Script Configures

### Phase 1 — System Configuration

| Setting | Method | Notes |
|---------|--------|-------|
| **Auto-login** | `sysadminctl -autologin set` | Server boots directly to desktop after power loss |
| **Sleep disabled** | `pmset -a sleep 0` | Prevents the machine from sleeping |
| **Disk sleep disabled** | `pmset -a disksleep 0` | Keeps drives always spinning |
| **Display sleep disabled** | `pmset -a displaysleep 0` | Display stays on (headless doesn't matter) |
| **Hibernation disabled** | `pmset -a hibernatemode 0` | No hibernation file written |
| **SSH enabled** | `systemsetup -setremotelogin on` | Opens port 22 via native sshd |
| **Application Firewall** | `socketfilterfw` | Enabled with sshd explicitly allowed |
| **GPU wired memory limit** | `/etc/sysctl.conf` | Dynamic value based on detected RAM (see table below) |

#### GPU Memory Table

The script detects the chip model and total unified memory at runtime and selects a value that maximizes memory available to AI models while leaving enough headroom for macOS.

| Unified RAM | `iogpu.wired_limit_mb` | OS Headroom |
|-------------|------------------------|-------------|
| 16 GB | 12,288 MB | 4 GB |
| 24 GB | 20,480 MB | 4 GB |
| 32 GB | 27,648 MB | 5 GB |
| 36 GB | 30,720 MB | 6 GB |
| 48 GB | 43,008 MB | 6 GB |
| 64 GB | 57,344 MB | 8 GB |
| 96 GB | 88,064 MB | 10 GB |
| 128 GB | 118,784 MB | 12 GB |
| 192 GB | 147,456 MB | 16 GB |
| Other | RAM − 16 GB | ~16 GB |

> ⚠️ Requires reboot to take effect.

---

### Phase 2 — Core Dependencies

| Tool | Version | Method | Notes |
|------|---------|--------|-------|
| **Xcode CLT** | Latest | `xcode-select --install` | Required for compiling Python |
| **Homebrew** | Latest | Official install script | Non-interactive; added to `~/.zshrc` |
| **Node.js** | Latest LTS | `brew install node` | JavaScript runtime |
| **pyenv** | Latest | `brew install pyenv` | Python version manager; init added to `~/.zshrc` |
| **Python** | 3.14 | `pyenv install 3.14` | Set as global default |
| **pip** | Latest | `pip install --upgrade pip` | Upgraded within pyenv environment |
| **psutil** | Latest | `pip install psutil` | System resource monitoring library |
| **Ollama** | Latest | Official install script | Local LLM runner |

---

### Phase 3 — Remote Access & Security

| Tool / Service | Method | Notes |
|----------------|--------|-------|
| **fail2ban** | `brew install fail2ban` | Intrusion prevention; blocks IPs on repeated auth failures |
| **Tailscale** | `brew install --cask tailscale` | Secure overlay network; added to login items |
| **RustDesk** | `brew install --cask rustdesk` | Remote desktop access; added to login items |

#### fail2ban Configuration

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `maxretry` | 5 | Failed SSH attempts before ban triggers |
| `findtime` | 1800 s (30 min) | Window in which failures are counted |
| `bantime` | 86400 s (24 hours) | How long a banned IP is blocked |
| `banaction` | `pf` | Uses macOS BSD packet filter for blocking |
| Log source | `/var/log/auth.log` | Routed from sshd via ASL rule |
| Startup | System LaunchDaemon | Starts at boot, before user login |

**How it works:**

1. sshd is configured to log auth events verbosely to the `AUTH` syslog facility
2. An ASL rule routes that facility to `/var/log/auth.log`
3. fail2ban watches that file and updates a `<fail2ban>` pf table when thresholds are exceeded
4. A dedicated pf anchor (`/etc/pf.anchors/fail2ban`) handles all blocking — the main `/etc/pf.conf` is only touched to load the anchor

**Adding more jails later:**
Edit `$BREW_PREFIX/etc/fail2ban/jail.local` and add new jail blocks below the marked comment line:

```ini
# ── Add additional jails below this line ──────────────────────
[nginx-http-auth]
enabled  = true
port     = http,https
filter   = nginx-http-auth
logpath  = /var/log/nginx/error.log
```

Then restart fail2ban:
```bash
launchctl kickstart -k system/com.openclaw.fail2ban
```

**Useful fail2ban commands:**
```bash
# Check status of all jails
sudo fail2ban-client status

# Check the SSH jail specifically
sudo fail2ban-client status sshd

# Unban an IP manually
sudo fail2ban-client set sshd unbanip <ip-address>

# View ban log
sudo cat /var/log/fail2ban.log
```

---

## Files Modified by the Script

| File | Change |
|------|--------|
| `/Library/Preferences/com.apple.loginwindow.plist` | Auto-login user set |
| `/etc/sysctl.conf` | `iogpu.wired_limit_mb` appended |
| `/etc/ssh/sshd_config` | `SyslogFacility AUTH` and `LogLevel VERBOSE` appended |
| `/etc/asl/com.openclaw.fail2ban` | Created — routes auth logs to `/var/log/auth.log` |
| `/var/log/auth.log` | Created if absent |
| `$BREW_PREFIX/etc/fail2ban/jail.local` | Created — fail2ban configuration |
| `/etc/pf.anchors/fail2ban` | Created — pf table and block rule |
| `/etc/pf.conf` | fail2ban anchor appended |
| `/Library/LaunchDaemons/com.openclaw.fail2ban.plist` | Created — system boot daemon |
| `~/.zshrc` | Homebrew shellenv and pyenv init appended (idempotent) |

---

## Idempotency

The script is safe to re-run. Every step that writes a file or modifies configuration checks first:

- Homebrew: checks if binary exists at `$BREW_PREFIX/bin/brew`
- Xcode CLT: checks `xcode-select -p`
- Homebrew in `.zshrc`: checks for `brew shellenv` string
- pyenv in `.zshrc`: checks for `PYENV_ROOT` string
- Python: uses `pyenv install --skip-existing`
- Ollama: checks `command -v ollama`
- GPU limit: checks for `iogpu.wired_limit_mb` in `/etc/sysctl.conf`
- sshd verbose logging: checks for `SyslogFacility AUTH` in `sshd_config`
- ASL rule: checks if `/etc/asl/com.openclaw.fail2ban` exists
- pf anchor: checks for `anchor.*fail2ban` in `/etc/pf.conf`

---

## Troubleshooting

**Auto-login didn't work after reboot**
Verify in System Settings → General → Users & Groups → Automatically log in as. If blank, FileVault may still be enabled — check with `fdesetup status`.

**GPU memory limit not applied**
Confirm a reboot occurred and check with:
```bash
sysctl iogpu.wired_limit_mb
```

**fail2ban not running**
Check the LaunchDaemon:
```bash
sudo launchctl list | grep fail2ban
sudo cat /var/log/fail2ban-error.log
```

**SSH auth.log is empty**
Restart the ASL daemon to pick up the new routing rule:
```bash
sudo launchctl kickstart -k system/com.apple.syslogd
```

**Homebrew or pyenv not found in new terminal sessions**
Source the shell config:
```bash
source ~/.zshrc
```
