#!/usr/bin/with-contenv bash
set -Eeuo pipefail

log() { echo "[cups-addon] $*"; }

# ----------------------------
# 1) Persistent directories
# ----------------------------
mkdir -p /data/cups/{config,logs,cache,state}
# make directories group-writable for lp group
find /data/cups -type d -exec chmod 775 {} + || true
chown -R root:lp /data/cups || true

# runtime dirs expected by cupsd
mkdir -p /run/cups
chown root:lp /run/cups || true

# ----------------------------
# 2) Seed once from /etc/cups
# ----------------------------
if [ ! -f /data/cups/config/.seeded ]; then
  if [ -d /etc/cups ]; then
    log "Seeding /data/cups/config from existing /etc/cups (first run)…"
    cp -a /etc/cups/. /data/cups/config/ 2>/dev/null || true
  fi
  touch /data/cups/config/.seeded
fi

# Ensure ppd directory exists in persistent config
mkdir -p /data/cups/config/ppd
chown -R root:lp /data/cups/config/ppd
chmod 775 /data/cups/config/ppd

# ----------------------------
# 3) Make /etc/cups persistent
# ----------------------------
rm -rf /etc/cups
ln -sfn /data/cups/config /etc/cups

# ----------------------------
# 4) Create default cupsd.conf if missing
#    (your LAN ACLs; no auth; logs/state under /data)
# ----------------------------
if [ ! -f /etc/cups/cupsd.conf ]; then
  log "Writing default /etc/cups/cupsd.conf…"
  cat > /etc/cups/cupsd.conf <<'EOC'
ServerRoot /data/cups/config
AccessLog /data/cups/logs/access_log
ErrorLog  /data/cups/logs/error_log
PageLog   /data/cups/logs/page_log
StateDir  /data/cups/state
CacheDir  /data/cups/cache
#LogLevel warn

# Listen on all interfaces
Listen 0.0.0.0:631

# Allow access from local network (no auth)
<Location />
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>

# Admin access (no authentication)
<Location /admin>
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>

# Job management permissions
<Location /jobs>
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>

WebInterface Yes
DefaultAuthType None
JobSheets none,none
PreserveJobHistory No
EOC
fi

# ----------------------------
# 5) printers.conf must exist with strict perms
#    (cupsd refuses too-permissive files)
# ----------------------------
touch /etc/cups/printers.conf
chown root:lp /etc/cups/printers.conf
chmod 600     /etc/cups/printers.conf

# match perms for other CUPS stateful files if present
for f in classes.conf subscriptions.conf; do
  if [ -f "/etc/cups/$f" ]; then
    chown root:lp "/etc/cups/$f"
    chmod 600     "/etc/cups/$f"
  fi
done

# ----------------------------
# 6) Start cupsd in foreground
# ----------------------------
log "Starting cupsd (foreground)…"
exec /usr/sbin/cupsd -f
