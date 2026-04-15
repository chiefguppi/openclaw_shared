#!/usr/bin/env bash
# =============================================================
# Mac Studio Server Initialization Script
# Run with: sudo bash init_mac_studio.sh
# =============================================================

set -euo pipefail

# ── Colors & helpers ──────────────────────────────────────────
GRN='\033[0;32m'; YLW='\033[1;33m'; BLU='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GRN}[✓]${NC} $*"; }
warn() { echo -e "${YLW}[!]${NC} $*"; }
info() { echo -e "${BLU}[→]${NC} $*"; }
fail() { echo -e "${RED}[✗]${NC} $*"; exit 1; }
hdr()  { echo -e "\n${BLU}══════════════════════════════════════${NC}\n  ${BLU}$*${NC}\n${BLU}══════════════════════════════════════${NC}"; }

# ── Root check & user detection ───────────────────────────────
[[ $EUID -eq 0 ]] || fail "Run with sudo: sudo bash $0"
REAL_USER="${SUDO_USER:-$(logname)}"
REAL_HOME=$(eval echo "~$REAL_USER")
ZSHRC="$REAL_HOME/.zshrc"

# ── Homebrew prefix (Apple Silicon vs Intel) ──────────────────
[[ $(uname -m) == "arm64" ]] && BREW_PREFIX="/opt/homebrew" || BREW_PREFIX="/usr/local"
BREW="$BREW_PREFIX/bin/brew"

# ── Helpers: run commands as the real user ────────────────────
as_user()  { sudo -u "$REAL_USER" "$@"; }
brew_cmd() { as_user "$BREW" "$@"; }

echo ""
echo "  Mac Studio Server Init"
echo "  User: $REAL_USER  |  Home: $REAL_HOME"
echo ""

# =============================================================
# PHASE 1 — SYSTEM CONFIGURATION
# =============================================================

hdr "Phase 1: System Configuration"

# ── Step 1: Auto-login ────────────────────────────────────────
info "Configuring auto-login for $REAL_USER..."
read -r -s -p "  Enter password for $REAL_USER: " USER_PASS; echo
sysadminctl -autologin set -userName "$REAL_USER" -password "$USER_PASS" \
    && ok "Auto-login set for $REAL_USER." \
    || warn "Auto-login failed — set manually in System Settings → Users & Groups."
unset USER_PASS

# ── Step 2: Power management ──────────────────────────────────
info "Disabling sleep and hibernation..."
pmset -a sleep 0 disksleep 0 displaysleep 0 hibernatemode 0
ok "Power management configured."

# ── Step 3: SSH ───────────────────────────────────────────────
info "Enabling SSH (Remote Login)..."
if systemsetup -setremotelogin on 2>/dev/null \
    || launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null; then
    ok "SSH enabled."
else
    warn "SSH enable failed — set manually in System Settings → Sharing."
fi

# ── Step 4: Network Firewall ──────────────────────────────────
info "Enabling network firewall and allowing SSH..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
/usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd
/usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/sbin/sshd
ok "Firewall enabled with SSH allowed."

# ── Step 5: GPU wired memory limit ────────────────────────────
info "Configuring GPU wired memory limit for AI models..."
CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Apple Silicon")
RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
info "Detected: $CHIP | ${RAM_GB}GB unified memory"

# GPU memory table — tuned headroom per config (RAM minus reserved OS memory)
# Keys are total RAM in GB; values are iogpu.wired_limit_mb
case $RAM_GB in
    16)  IOGPU_MB=12288  ;;  # 16 - 4 GB reserved
    24)  IOGPU_MB=20480  ;;  # 24 - 4 GB reserved
    32)  IOGPU_MB=27648  ;;  # 32 - 5 GB reserved
    36)  IOGPU_MB=30720  ;;  # 36 - 6 GB reserved
    48)  IOGPU_MB=43008  ;;  # 48 - 6 GB reserved
    64)  IOGPU_MB=57344  ;;  # 64 - 8 GB reserved
    96)  IOGPU_MB=88064  ;;  # 96 - 10 GB reserved
    128) IOGPU_MB=118784 ;;  # 128 - 12 GB reserved
    192) IOGPU_MB=147456 ;;  # 192 - 16 GB reserved
    *)   IOGPU_MB=$(( (RAM_GB - 16) * 1024 )) ;;  # fallback: leave ~16 GB free
esac

if grep -q "iogpu.wired_limit_mb" /etc/sysctl.conf 2>/dev/null; then
    ok "iogpu.wired_limit_mb already set in /etc/sysctl.conf — skipping."
else
    echo "iogpu.wired_limit_mb=${IOGPU_MB}" >> /etc/sysctl.conf
    ok "iogpu.wired_limit_mb=${IOGPU_MB} written to /etc/sysctl.conf (${RAM_GB}GB config)."
fi
warn "GPU memory limit requires a reboot to take effect."

# =============================================================
# PHASE 2 — CORE DEPENDENCIES
# =============================================================

hdr "Phase 2: Core Dependencies"

# ── Step 4: Xcode CLT ─────────────────────────────────────────
if xcode-select -p &>/dev/null; then
    ok "Xcode Command Line Tools already installed."
else
    info "Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    warn "A system dialog has opened to install Xcode Command Line Tools."
    read -r -p "  Press Enter once the installation is complete..."
    ok "Xcode Command Line Tools installed."
fi

# ── Step 5: Homebrew ──────────────────────────────────────────
if [[ -x "$BREW" ]]; then
    ok "Homebrew already installed."
else
    info "Installing Homebrew (non-interactive)..."
    as_user env NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew installed."
fi
if ! grep -q "brew shellenv" "$ZSHRC" 2>/dev/null; then
    as_user bash -c "echo 'eval \"\$(${BREW_PREFIX}/bin/brew shellenv)\"' >> \"$ZSHRC\""
    ok "Homebrew shell env added to ~/.zshrc."
fi
eval "$("$BREW" shellenv)" 2>/dev/null || export PATH="$BREW_PREFIX/bin:$PATH"

# ── Step 6: Node.js ───────────────────────────────────────────
info "Installing Node.js..."
brew_cmd install node
ok "Node.js installed: $(as_user node --version 2>/dev/null || echo 'open a new shell to verify')"

# ── Step 7: pyenv ─────────────────────────────────────────────
info "Installing pyenv..."
brew_cmd install pyenv
if ! grep -q "PYENV_ROOT" "$ZSHRC" 2>/dev/null; then
    as_user tee -a "$ZSHRC" > /dev/null <<'PYENV_BLOCK'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
PYENV_BLOCK
    ok "pyenv init added to ~/.zshrc."
else
    ok "pyenv already configured in ~/.zshrc."
fi

# ── Step 8: Python 3.14 ───────────────────────────────────────
warn "Installing Python 3.14 via pyenv — this may take 10–20 minutes..."
as_user env \
    PYENV_ROOT="$REAL_HOME/.pyenv" \
    PATH="$REAL_HOME/.pyenv/bin:$BREW_PREFIX/bin:$PATH" \
    bash -c '
        eval "$(pyenv init -)"
        pyenv install 3.14 --skip-existing
        pyenv global 3.14
        echo "  Python version: $(python --version)"
    '
ok "Python 3.14 installed and set as global."

# ── Step 8b: pip upgrade + psutil ────────────────────────────
info "Upgrading pip and installing psutil..."
as_user env \
    PYENV_ROOT="$REAL_HOME/.pyenv" \
    PATH="$REAL_HOME/.pyenv/bin:$BREW_PREFIX/bin:$PATH" \
    bash -c '
        eval "$(pyenv init -)"
        pip install --upgrade pip
        pip install psutil
    '
ok "pip upgraded and psutil installed."

# ── Step 9: Ollama ────────────────────────────────────────────
if as_user command -v ollama &>/dev/null; then
    ok "Ollama already installed."
else
    info "Installing Ollama..."
    if as_user bash -c "curl -fsSL https://ollama.com/install.sh | sh"; then
        ok "Ollama installed."
    else
        warn "Ollama install failed — install manually: https://ollama.com"
    fi
fi

# =============================================================
# PHASE 3 — REMOTE ACCESS
# =============================================================

hdr "Phase 3: Remote Access"

# ── Step 10: fail2ban ─────────────────────────────────────────
info "Installing fail2ban..."
brew_cmd install fail2ban

# -- 10a: Enable verbose sshd logging to AUTH facility (idempotent)
if ! grep -q "^SyslogFacility AUTH" /etc/ssh/sshd_config 2>/dev/null; then
    printf '\n# Verbose auth logging for fail2ban\nSyslogFacility AUTH\nLogLevel VERBOSE\n' \
        >> /etc/ssh/sshd_config
    ok "sshd verbose logging configured."
else
    ok "sshd verbose logging already set."
fi

# -- 10b: Route AUTH syslog facility to /var/log/auth.log via ASL
if [[ ! -f /etc/asl/com.openclaw.fail2ban ]]; then
    cat > /etc/asl/com.openclaw.fail2ban <<'ASL'
? [= Facility auth] file /var/log/auth.log mode=0640 format=bsd rotate=seq compress file_max=5M ttl=7
ASL
    ok "ASL routing: auth facility → /var/log/auth.log"
fi
touch /var/log/auth.log && chmod 640 /var/log/auth.log

# -- 10c: Write jail.local
# bantime=24h, findtime=30min, maxretry=5; comment block marks where to add future jails
mkdir -p "$BREW_PREFIX/etc/fail2ban"
cat > "$BREW_PREFIX/etc/fail2ban/jail.local" <<'JAIL'
[DEFAULT]
bantime  = 86400   ; 24 hours
findtime = 1800    ; 30-minute detection window
maxretry = 5       ; failed attempts before ban
banaction = pf
banaction_allports = pf

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log

# ── Add additional jails below this line ──────────────────────
JAIL
ok "fail2ban jail.local written (5 retries / 30 min window / 24h ban)."

# -- 10d: Configure a dedicated pf anchor so fail2ban never touches pf.conf directly
mkdir -p /etc/pf.anchors
if [[ ! -f /etc/pf.anchors/fail2ban ]]; then
    cat > /etc/pf.anchors/fail2ban <<'PF'
table <fail2ban> persist
block in quick from <fail2ban>
PF
fi
if ! grep -q "anchor.*fail2ban" /etc/pf.conf 2>/dev/null; then
    printf '\n# fail2ban\nanchor "fail2ban"\nload anchor "fail2ban" from "/etc/pf.anchors/fail2ban"\n' \
        >> /etc/pf.conf
    ok "pf anchor added to /etc/pf.conf."
else
    ok "pf anchor already present."
fi
pfctl -f /etc/pf.conf 2>/dev/null && pfctl -e 2>/dev/null || true

# -- 10e: Install as system-level LaunchDaemon (starts at boot, before login)
cat > /Library/LaunchDaemons/com.openclaw.fail2ban.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.fail2ban</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BREW_PREFIX}/bin/fail2ban-server</string>
        <string>-xf</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/var/log/fail2ban-error.log</string>
</dict>
</plist>
PLIST
launchctl load -w /Library/LaunchDaemons/com.openclaw.fail2ban.plist
ok "fail2ban LaunchDaemon installed (starts at boot)."

# -- 10f: Restart sshd to pick up verbose logging config
launchctl kickstart -k system/com.openssh.sshd 2>/dev/null \
    || launchctl stop com.openssh.sshd 2>/dev/null || true
ok "sshd restarted with verbose logging."

# ── Step 12: Tailscale ────────────────────────────────────────
info "Installing Tailscale..."
brew_cmd install --cask tailscale
ok "Tailscale installed."

# ── Step 13: RustDesk ─────────────────────────────────────────
info "Installing RustDesk..."
brew_cmd install --cask rustdesk
ok "RustDesk installed."

# ── Step 14: Login items ──────────────────────────────────────
info "Adding Tailscale and RustDesk to login items..."
as_user osascript <<'APPLESCRIPT' 2>/dev/null \
    || warn "Could not set login items — add manually in System Settings → General → Login Items."
tell application "System Events"
    set loginApps to {"/Applications/Tailscale.app", "/Applications/RustDesk.app"}
    repeat with appPath in loginApps
        try
            make login item at end with properties {path:appPath, hidden:false}
        end try
    end repeat
end tell
APPLESCRIPT
ok "Login items configured."

# =============================================================
# SUMMARY
# =============================================================

echo ""
echo "══════════════════════════════════════"
echo "  Setup Complete"
echo "══════════════════════════════════════"
echo ""
ok "Auto-login:        $REAL_USER"
ok "Power management:  sleep/hibernate disabled"
ok "SSH:               port 22 open"
ok "Firewall:          enabled, SSH allowed"
ok "GPU memory:        iogpu.wired_limit_mb=${IOGPU_MB} for ${RAM_GB}GB (reboot required)"
ok "Xcode CLT:         installed"
ok "Homebrew:          installed"
ok "Node.js:           installed"
ok "pyenv + Python:    3.14 (global)"
ok "pip:               upgraded"
ok "psutil:            installed"
ok "Ollama:            installed"
ok "fail2ban:          installed (5 retries / 30 min / 24h ban)"
ok "Tailscale:         installed"
ok "RustDesk:          installed"
ok "Login items:       Tailscale, RustDesk"
echo ""
warn "MANUAL STEPS REMAINING:"
echo ""
echo "  1. Authenticate Tailscale:"
echo "     Open Tailscale → log in to your tailnet"
echo "     Settings → Launch at login ✓"
echo "     VPN On Demand → Always Run"
echo ""
echo "  2. Copy SSH key from your client machine:"
echo "     ssh-copy-id $REAL_USER@<mac-studio-ip>"
echo ""
echo "  3. (Optional) Configure RustDesk self-hosted relay server"
echo ""
