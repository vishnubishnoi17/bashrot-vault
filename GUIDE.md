# Bashrot Vault System — Full Operational Guide

> **The story:** Yashwant (warden) has secured his Bashrots in an encoded vault. Skndash (basher) wants to crack it. Guards monitor everything. This guide tells you exactly what to run, on which user, and when.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [First-Time Setup](#first-time-setup)
3. [Known Gotchas & Fixes](#known-gotchas--fixes)
4. [Running a Full Game Round](#running-a-full-game-round)
5. [Resetting for a New Round](#resetting-for-a-new-round)
6. [What Runs Automatically](#what-runs-automatically)
7. [All Commands by User](#all-commands-by-user)
8. [Permissions Reference](#permissions-reference)
9. [Troubleshooting](#troubleshooting)

---

## System Overview

| Role | User | Group | Home | Purpose |
|------|------|-------|------|---------|
| Warden | `yashwant` | `wardens` | `/home/wardens/yashwant/` | Admin — runs leaderboard, monitors heists |
| Guard | `guard1`, `guard2` | `guards` | `/home/guards/` | Reads logs, runs taxLeaderboard |
| Basher | `skndash`, `basher2` | `bashers` | `/home/bashers/` | Players — crack the vault |

Key paths:

```
/scripts/                  — all game scripts (in PATH)
/opt/Bashrot_vault/        — the secured vault (bashers locked out)
/opt/Bashrot_vault/.shadow_corridor/   — execute-only for bashers (blind navigate)
/opt/Bashrot_vault/.symlinks/          — 6767 symlinks, one points to real encoded file
/etc/vault/roster.yaml     — user config
/etc/vault/slang.txt       — the word list (source of all encoded files)
/var/log/vault/            — all logs
```

---

## First-Time Setup

Run these **once only**, in order, from your main terminal as root.

### Step 1 — Install everything

```bash
cd vault_system/
cd scripts
sudo bash install.sh
```

Installs dependencies (`acl`, `jp2a`, `curl`, `yq`, `bc`), copies all scripts to `/scripts/`, sets permissions, registers systemd services, and sets up cron jobs.

### Step 2 — Edit the roster

```bash
sudo nano /etc/vault/roster.yaml
```

Fill in real usernames and SSH public keys for bashers. Format:

```yaml
wardens:
  - username: yashwant
    image_url: "https://api.dicebear.com/7.x/pixel-art/svg?seed=yashwant"

guards:
  - username: guard1
    image_url: "https://api.dicebear.com/7.x/pixel-art/svg?seed=guard1"

bashers:
  - username: skndash
    image_url: "https://api.dicebear.com/7.x/pixel-art/svg?seed=skndash"
    ssh_public_key: "ssh-ed25519 AAAA... skndash@machine"
```

### Step 3 — Provision users

```bash
sudo initRoster /etc/vault/roster.yaml
```

### Step 4 — Build the vault

```bash
sudo secureVault
```

### Step 5 — Set passwords for warden and guards

Bashers have password login disabled by design. Wardens and guards need passwords set manually:

```bash
sudo passwd yashwant
sudo passwd guard1
sudo passwd guard2
```

### Step 6 — Add yashwant to sudoers

```bash
sudo usermod -aG sudo yashwant
```

### Step 7 — Start background services

```bash
sudo systemctl start generateLore verifyHeist
```

### Step 8 — Populate symlinks immediately

```bash
sudo noCapSecurity
```

### Step 9 — Fix vault traversal for bashers

By default bashers cannot traverse the vault root to reach `.shadow_corridor`. Fix:

```bash
sudo setfacl -m "g:bashers:--x" /opt/Bashrot_vault/
```

### Step 10 — Allow bashers to read the real hidden file

The hidden file is created with `root:wardens 640`. Run this before every round so bashers can decode it:

```bash
# Find the current hidden file path
sudo cat /var/run/vault/real_encoded_location

# Grant bashers read access (replace path with the one above)
sudo setfacl -m "g:bashers:r--" /path/shown/above
```

---

## Known Gotchas & Fixes

### ❌ `su - skndash` → Authentication failure

**Why:** Bashers have their passwords locked by design (`passwd -l`). They are meant to SSH in via key only, or be switched to via sudo.

**Fix:** Never use `su` for bashers. Always use:
```bash
sudo -u skndash -i
```

### ❌ `su - yashwant` → Authentication failure

**Why:** No password was set for yashwant.

**Fix:**
```bash
sudo passwd yashwant
# then su - yashwant works
```

### ❌ `cd /opt/Bashrot_vault/.shadow_corridor/` → Permission denied (as skndash)

**Why:** Bashers have `---` on the vault root, so they can't traverse it to reach the corridor.

**Fix (run once as root):**
```bash
sudo setfacl -m "g:bashers:--x" /opt/Bashrot_vault/
```

### ❌ `base64 -d /opt/Bashrot_vault/.symlinks/lure_XXXXX` → Permission denied

**Why:** The real symlink points to a hidden file owned `root:wardens 640`. Bashers can't read it.

**Fix (run each round as root):**
```bash
sudo cat /var/run/vault/real_encoded_location
sudo setfacl -m "g:bashers:r--" /path/from/above
```

### ❌ `sudo trendSetters` → yashwant is not in the sudoers file

**Fix:**
```bash
# From main terminal as root:
sudo usermod -aG sudo yashwant
# Then re-login as yashwant
exit && su - yashwant
```

### ❌ `trendSetters` → leaderboard.log: No such file or directory

**Why:** Log is created on first run. Just run without sudo:
```bash
trendSetters
```

---

## Running a Full Game Round

Open **3 terminal tabs**.

---

### Tab 1 — Main terminal (your root/admin shell)

Run the hidden file fix before the game starts:

```bash
sudo cat /var/run/vault/real_encoded_location
sudo setfacl -m "g:bashers:r--" /path/shown/above
```

Nothing else needed here during the round.

---

### Tab 2 — Yashwant (Warden)

```bash
su - yashwant
# password: whatever you set with passwd yashwant

# Watch heist attempts live
tail -f /var/log/vault/heist.log

# After a heist, check the leaderboard
trendSetters

# Check if skndash has been racking up penalties
cat /home/wardens/yashwant/skndash.txt
```

---

### Tab 3 — Skndash (Basher)

```bash
sudo -u skndash -i
# Avatar prints on login, slang aliases load
```

**Step 1 — Find the real symlink** (the one pointing to a file, not a directory):

```bash
for link in /opt/Bashrot_vault/.symlinks/lure_*; do
    [ -f "$link" ] && echo "FOUND: $link" && break
done
```

**Step 2 — Decode it** (replace XXXXX with number from step 1):

```bash
base64 -d /opt/Bashrot_vault/.symlinks/lure_XXXXX
```

**Step 3 — Drop the decoded word into Drop_Zone** (replace `rizz` with whatever step 2 printed):

```bash
echo -n "rizz" > ~/Drop_Zone/heist1.txt
```

Within **5 seconds**, `verifyHeist` detects the file. If the word matches, every terminal on the system gets:

```
🔥 HEIST SUCCESSFUL! Basher 'skndash' cracked the vault and stole 'rizz'! 🔥
```

---

### Skndash's slang aliases (available in his shell)

| Type this | Does this |
|-----------|-----------|
| `cap` | `clear` |
| `sus` | `ls -la` |
| `mog` | `tail -n 20` |
| `rizz` | `whoami` |
| `vibe` | `uptime` |
| `bussin` | `df -h` |

---

### The blind corridor (optional challenge)

Skndash has execute-only access to `.shadow_corridor` — he can `cd` in but not `ls`:

```bash
cd /opt/Bashrot_vault/.shadow_corridor/
ls        # Permission denied — intentional, he's navigating blind
```

---

## Resetting for a New Round

```bash
# Step 1 — Warden panic button (from yashwant's tab or main terminal)
sudo wipeTimeline
# type CONFIRM when prompted
# This: stops services, wipes basher files, clears vault, resets ACLs, restarts services

# Step 2 — Rotate symlinks to new random locations
sudo noCapSecurity
# Note the new real symlink index in the output

# Step 3 — Re-grant basher read access to the new hidden file
sudo cat /var/run/vault/real_encoded_location
sudo setfacl -m "g:bashers:r--" /path/shown/above

# Step 4 — Game is live again. Back to skndash's tab.
```

---

## What Runs Automatically

| Process | How | Schedule |
|---------|-----|----------|
| `generateLore` | systemd service | Every 30 seconds — encodes a random slang word into the vault |
| `verifyHeist` | systemd service | Every 5 seconds — checks Drop_Zone of every basher |
| `collectTax` | cron | Every 5 min, **Fridays & Saturdays only** — deletes oldest files if basher exceeds 5MB |
| `noCapSecurity` | cron | Every 45 minutes — rotates all 6767 symlinks to new random locations |
| `checkDemotions` | cron | Every minute — restores bashers from rbash after 30-min penalty expires |

Check service status anytime:

```bash
sudo systemctl status generateLore
sudo systemctl status verifyHeist
sudo journalctl -u generateLore -f      # live log
sudo journalctl -u verifyHeist -f       # live log
```

---

## All Commands by User

### Root / Main Terminal

```bash
# One-time fixes
sudo setfacl -m "g:bashers:--x" /opt/Bashrot_vault/
sudo usermod -aG sudo yashwant
sudo passwd yashwant && sudo passwd guard1 && sudo passwd guard2

# Each round — grant basher read on hidden file
sudo cat /var/run/vault/real_encoded_location
sudo setfacl -m "g:bashers:r--" /path/from/above

# Reset simulation
sudo wipeTimeline        # type CONFIRM

# Rotate symlinks
sudo noCapSecurity

# Re-provision users after editing roster
sudo initRoster /etc/vault/roster.yaml

# Re-build vault (after wipe or from scratch)
sudo secureVault

# Service management
sudo systemctl start generateLore verifyHeist
sudo systemctl status generateLore
sudo journalctl -u generateLore -f
```

---

### Yashwant (Warden)

```bash
su - yashwant

# Monitor heists live
tail -f /var/log/vault/heist.log

# Leaderboard (top 3 bashers with scores)
trendSetters

# Check a basher's penalty violations
cat /home/wardens/yashwant/skndash.txt

# Find the real symlink (cheat view)
sudo cat /var/run/vault/real_encoded_location
```

---

### Guard1 / Guard2

```bash
su - guard1

# Tax leaderboard (who got taxed most)
taxLeaderboard

# Read heist log
cat /var/log/vault/heist.log

# Read leaderboard log
cat /var/log/vault/leaderboard.log
```

---

### Skndash (Basher)

```bash
sudo -u skndash -i

# Find the real symlink
for link in /opt/Bashrot_vault/.symlinks/lure_*; do
    [ -f "$link" ] && echo "FOUND: $link" && break
done

# Decode the encoded word
base64 -d /opt/Bashrot_vault/.symlinks/lure_XXXXX

# Drop the decoded word to win
echo -n "decoded_word" > ~/Drop_Zone/heist1.txt

# Blind navigate the shadow corridor
cd /opt/Bashrot_vault/.shadow_corridor/

# Slang aliases
cap        # clear screen
sus        # ls -la
mog        # tail -n 20
rizz       # whoami
vibe       # uptime
bussin     # df -h
```

---

## Permissions Reference

### Script Access

| Script | root | wardens | guards | bashers |
|--------|------|---------|--------|---------|
| `initRoster` | ✅ | ✅ | ❌ | ❌ |
| `secureVault` | ✅ | ✅ | ❌ | ❌ |
| `generateLore` | ✅ | ❌ | ❌ | ❌ |
| `collectTax` | ✅ | ❌ | ❌ | ❌ |
| `taxLeaderboard` | ✅ | ✅ | ✅ | ❌ |
| `verifyHeist` | ✅ | ✅ | ❌ | ❌ |
| `trendSetters` | ✅ | ✅ | ❌ | ❌ |
| `wipeTimeline` | ✅ | ✅ | ❌ | ❌ |
| `noCapSecurity` | ✅ | ❌ | ❌ | ❌ |

### Vault ACLs

| Path | wardens | guards | bashers |
|------|---------|--------|---------|
| `/opt/Bashrot_vault/` | rwx | rwx | --x (after fix) |
| `/.shadow_corridor/` | rwx | rwx | --x |
| `/.symlinks/` | rwx | r-x | r-x |
| `.enc` files | rw- | rw- | --- |

### Log Access

| Log | wardens | guards | bashers |
|-----|---------|--------|---------|
| `heist.log` | rw- | r-- | --- |
| `tax.log` | rw- | rw- | --- |
| `leaderboard.log` | rw- | r-- | --- |
| `penalty_audit.log` | rw- | --- | --- |

### Basher Home Dirs

| Path | owner basher | guards | wardens | other bashers |
|------|-------------|--------|---------|---------------|
| `/home/bashers/<user>/` | rwx | r-x | r-x | --- |
| `/home/bashers/<user>/Drop_Zone/` | rwx | r-x | rwx | --- |

---

## Troubleshooting

**`yq: command not found`**
```bash
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

**`setfacl: command not found`**
```bash
sudo apt-get install acl
```

**ACL operations fail: "Operation not supported"**
```bash
sudo mount -o remount,acl /
# Permanently — add "acl" to root entry in /etc/fstab
```

**`jp2a: command not found`**
```bash
sudo apt-get install jp2a
```

**`generateLore` not starting**
```bash
sudo journalctl -u generateLore --no-pager
# Check: does /etc/vault/slang.txt exist?
# Check: does /opt/Bashrot_vault/ exist? Run secureVault first.
```

**verifyHeist not detecting Drop_Zone files**

File content must exactly match a word in `/etc/vault/slang.txt` with no trailing newline. Always use:
```bash
echo -n "word" > ~/Drop_Zone/file.txt   # -n = no newline
# NOT: echo "word" > ...               # adds newline, won't match
```

**Penalty system — skndash gets demoted to rbash**

He triggered 100+ penalty points. He's locked to rbash for 30 minutes. Wait it out, or restore manually:
```bash
sudo usermod -s /bin/bash skndash
sudo rm -f /var/run/vault/demoted_skndash
```

Check his penalty score:
```bash
cat /home/wardens/yashwant/skndash.txt
```

**noCapSecurity rotated — symlinks changed**

Every 45 minutes the real symlink index changes. If `base64 -d` gives permission denied after finding a link, the rotation happened mid-round. Re-run:
```bash
sudo cat /var/run/vault/real_encoded_location
sudo setfacl -m "g:bashers:r--" /new/path/shown/above
```

**View all cron jobs**
```bash
sudo crontab -l
```

**View all vault logs**
```bash
ls /var/log/vault/
tail -f /var/log/vault/heist.log
tail -f /var/log/vault/generateLore.log
```