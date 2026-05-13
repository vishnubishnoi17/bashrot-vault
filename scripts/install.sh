#!/bin/bash
# =============================================================================
# install.sh — Deploy all vault scripts, set permissions, and configure cron
# Run as root. Usage: sudo bash install.sh
# Must be run from inside the scripts/ directory.
# =============================================================================
set -euo pipefail

SCRIPTS_SRC="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DST="/scripts"
LOG_DIR="/var/log/vault"
LOG="${LOG_DIR}/install.log"

mkdir -p "$SCRIPTS_DST" "$LOG_DIR"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

[[ $EUID -eq 0 ]] || { echo "ERROR: Run as root (sudo bash install.sh)"; exit 1; }

log "=== Installing Vault System ==="
log "Source directory: $SCRIPTS_SRC"

# ── Install dependencies ──────────────────────────────────────────────────────
log "Installing dependencies (ignoring broken repo errors)..."
apt-get update -qq 2>/dev/null || {
    log "WARNING: apt-get update had errors (likely broken 3rd party repo). Continuing..."
    apt-get update --allow-releaseinfo-change -qq 2>/dev/null || true
}

for pkg in acl jp2a curl wget bc inotify-tools; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        log "  $pkg already installed — skipping."
    else
        apt-get install -y -qq "$pkg" 2>/dev/null \
            && log "  Installed: $pkg" \
            || log "  WARNING: Could not install $pkg"
    fi
done

# ── Install yq ────────────────────────────────────────────────────────────────
if command -v yq &>/dev/null && yq --version 2>&1 | grep -q "mikefarah"; then
    log "yq (mikefarah) already installed: $(yq --version)"
else
    log "Installing yq..."
    wget -qO /usr/local/bin/yq \
        https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
        && chmod +x /usr/local/bin/yq \
        && log "yq installed: $(yq --version)" \
        || { log "ERROR: Failed to download yq."; exit 1; }
fi

log "Dependencies ready."

# ── Copy all scripts to /scripts ─────────────────────────────────────────────
log "Copying scripts to $SCRIPTS_DST..."

SCRIPT_NAMES=(
    initRoster secureVault generateLore collectTax
    taxLeaderboard verifyHeist trendSetters wipeTimeline
    theLPenalty noCapSecurity checkDemotions
)

for script in "${SCRIPT_NAMES[@]}"; do
    if [[ -f "$SCRIPTS_SRC/$script" ]]; then
        cp "$SCRIPTS_SRC/$script" "$SCRIPTS_DST/"
        log "  Copied: $script"
    else
        log "  WARNING: $script not found in $SCRIPTS_SRC — skipping."
    fi
done

# Copy service files
for svc in generateLore.service verifyHeist.service; do
    if [[ -f "$SCRIPTS_SRC/$svc" ]]; then
        cp "$SCRIPTS_SRC/$svc" /etc/systemd/system/
        log "  Copied: $svc → /etc/systemd/system/"
    else
        log "  WARNING: $svc not found — skipping."
    fi
done

chmod +x "$SCRIPTS_DST"/* 2>/dev/null || true
log "All scripts marked executable."

# ── Ensure groups exist ───────────────────────────────────────────────────────
log "Creating system groups..."
for grp in bashers guards wardens; do
    getent group "$grp" &>/dev/null \
        && log "  Group $grp already exists." \
        || { groupadd "$grp"; log "  Created group: $grp"; }
done

# ── Set correct ownership and permissions ─────────────────────────────────────
log "Setting script permissions..."

# Warden-only scripts: root:wardens 750
for script in initRoster secureVault verifyHeist trendSetters wipeTimeline noCapSecurity; do
    [[ -f "$SCRIPTS_DST/$script" ]] || continue
    chown root:wardens "$SCRIPTS_DST/$script"
    chmod 750 "$SCRIPTS_DST/$script"
    log "  $script → root:wardens 750"
done

# Guard+warden: root:guards 750 + wardens ACL
chown root:guards "$SCRIPTS_DST/taxLeaderboard"
chmod 750 "$SCRIPTS_DST/taxLeaderboard"
setfacl -m "g:wardens:r-x" "$SCRIPTS_DST/taxLeaderboard"
log "  taxLeaderboard → root:guards 750 + wardens ACL"

# Root-only daemons/cron
for script in generateLore collectTax checkDemotions; do
    [[ -f "$SCRIPTS_DST/$script" ]] || continue
    chown root:root "$SCRIPTS_DST/$script"
    chmod 700 "$SCRIPTS_DST/$script"
    log "  $script → root:root 700"
done

# theLPenalty: sourced by bashers — must be readable
chown root:root "$SCRIPTS_DST/theLPenalty"
chmod 644 "$SCRIPTS_DST/theLPenalty"
log "  theLPenalty → 644 (sourced by shells)"

# ── Add /scripts to system PATH ───────────────────────────────────────────────
log "Adding /scripts to PATH..."

if grep -q '^PATH=' /etc/environment 2>/dev/null; then
    grep -q '/scripts' /etc/environment || \
        sed -i 's|^PATH="\(.*\)"|PATH="/scripts:\1"|' /etc/environment
else
    echo 'PATH="/scripts:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' \
        >> /etc/environment
fi

cat > /etc/profile.d/vault_path.sh <<'EOF'
export PATH="/scripts:$PATH"
EOF
chmod 644 /etc/profile.d/vault_path.sh

log "Creating symlinks in /usr/local/bin for immediate sudo access..."
for script in "${SCRIPT_NAMES[@]}"; do
    [[ -f "$SCRIPTS_DST/$script" ]] || continue
    ln -sf "$SCRIPTS_DST/$script" "/usr/local/bin/$script" 2>/dev/null \
        && log "  Symlinked: /usr/local/bin/$script → $SCRIPTS_DST/$script" \
        || log "  WARNING: Could not symlink $script"
done

log "PATH configured."

# ── Enable ACL on filesystem ──────────────────────────────────────────────────
log "Checking ACL support..."
MOUNT_OPTS=$(mount | grep " on / " | head -1)
if echo "$MOUNT_OPTS" | grep -q "acl"; then
    log "ACL already active on root filesystem."
else
    log "ACL not active — enabling now..."
    mount -o remount,acl / 2>/dev/null \
        && log "ACL enabled via remount." \
        || log "WARNING: Could not remount with ACL."
    FSTAB="/etc/fstab"
    if grep -q " / " "$FSTAB" && ! grep " / " "$FSTAB" | grep -q "acl"; then
        sed -i '/[[:space:]]\/[[:space:]]/ s/defaults/defaults,acl/' "$FSTAB" \
            && log "Added acl to /etc/fstab root entry." \
            || log "WARNING: Could not update /etc/fstab automatically."
    fi
fi

# ── Create /etc/vault config directory ───────────────────────────────────────
log "Setting up /etc/vault..."
mkdir -p /etc/vault
chown root:wardens /etc/vault
chmod 750 /etc/vault

if [[ ! -f /etc/vault/roster.yaml ]]; then
    [[ -f "$SCRIPTS_SRC/roster.yaml" ]] \
        && cp "$SCRIPTS_SRC/roster.yaml" /etc/vault/ \
        && log "Copied sample roster.yaml to /etc/vault/" \
        || log "NOTE: No roster.yaml found — create /etc/vault/roster.yaml manually."
else
    log "/etc/vault/roster.yaml already exists — not overwriting."
fi

# ── Install systemd services ──────────────────────────────────────────────────
systemctl daemon-reload

for svc in generateLore verifyHeist; do
    svc_file="/etc/systemd/system/${svc}.service"
    if [[ -f "$svc_file" ]]; then
        log "Installing ${svc} systemd service..."
        systemctl enable "$svc" 2>/dev/null && log "  Service ${svc} enabled."
    else
        log "WARNING: ${svc}.service not found — service not installed."
    fi
done

# Only start services if the vault already exists (i.e. secureVault was run)
if [[ -d /opt/Bashrot_vault ]]; then
    systemctl start generateLore 2>/dev/null && log "generateLore started." \
        || log "WARNING: generateLore failed to start."
    systemctl start verifyHeist 2>/dev/null && log "verifyHeist started." \
        || log "WARNING: verifyHeist failed to start."
else
    log "NOTE: Services not started yet — run secureVault first, then:"
    log "      sudo systemctl start generateLore"
    log "      sudo systemctl start verifyHeist"
fi

# ── Inject theLPenalty hook into /etc/bash.bashrc ────────────────────────────
log "Injecting penalty hook into /etc/bash.bashrc..."
PENALTY_MARKER="# === VAULT PENALTY HOOK ==="
if ! grep -qF "$PENALTY_MARKER" /etc/bash.bashrc 2>/dev/null; then
    cat >> /etc/bash.bashrc <<'EOF'

# === VAULT PENALTY HOOK ===
if id -Gn 2>/dev/null | grep -qw "bashers"; then
    source /scripts/theLPenalty 2>/dev/null || true
fi
EOF
    log "Penalty hook injected into /etc/bash.bashrc"
else
    log "Penalty hook already present — skipping."
fi

# ── Set up cron jobs ──────────────────────────────────────────────────────────
log "Setting up cron jobs..."
CRON_TAX="*/5 * * * 5,6 /scripts/collectTax >> /var/log/vault/collectTax.log 2>&1"
CRON_NOCAP="*/45 * * * * /scripts/noCapSecurity >> /var/log/vault/noCapSecurity.log 2>&1"
CRON_DEMOTE="* * * * * /scripts/checkDemotions >> /var/log/vault/checkDemotions.log 2>&1"

(crontab -l 2>/dev/null | grep -v "collectTax\|noCapSecurity\|checkDemotions"; \
    echo "$CRON_TAX"; echo "$CRON_NOCAP"; echo "$CRON_DEMOTE") | crontab -
log "Cron jobs installed:"
log "  collectTax    — every 5 min on Fri+Sat"
log "  noCapSecurity — every 45 min"
log "  checkDemotions — every 1 min (restores rbash after 30 min)"

# ── Final summary ─────────────────────────────────────────────────────────────
log "=== Installation complete ==="

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║          ✅  VAULT SYSTEM INSTALLED                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "NEXT STEPS:"
echo "  1. Edit the roster:    sudo nano /etc/vault/roster.yaml"
echo "  2. Provision users:    sudo initRoster /etc/vault/roster.yaml"
echo "  3. Build the vault:    sudo secureVault"
echo "  4. Start services:     sudo systemctl start generateLore verifyHeist"
echo ""
echo "Scripts installed in: $SCRIPTS_DST"
echo "Symlinked to:         /usr/local/bin/"
echo "Logs:                 /var/log/vault/"
echo ""
ls -la "$SCRIPTS_DST/"
