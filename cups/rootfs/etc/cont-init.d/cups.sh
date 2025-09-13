#!/usr/bin/with-contenv bash
set -e

mkdir -p /data/cups/{cache,logs,state,config}
chown -R root:lp /data/cups
chmod -R 775 /data/cups

mkdir -p /etc/cups

# Only create cupsd.conf if it DOESN’T exist (don’t overwrite user edits)
if [ ! -f /data/cups/config/cupsd.conf ]; then
  cat > /data/cups/config/cupsd.conf <<'EOL'
ServerRoot /data/cups/config
AccessLog /data/cups/logs/access_log
ErrorLog  /data/cups/logs/error_log
PageLog   /data/cups/logs/page_log
StateDir  /data/cups/state
CacheDir  /data/cups/cache

# Listen on all interfaces
Listen 0.0.0.0:631

# Allow access from local network
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
EOL
fi

# Ensure printers.conf exists with CUPS-friendly perms so CUPS can write it
touch /data/cups/config/printers.conf
chown root:lp /data/cups/config/printers.conf
chmod 600   /data/cups/config/printers.conf

# Symlinks so cupsd uses the persistent files
ln -sf /data/cups/config/cupsd.conf     /etc/cups/cupsd.conf
ln -sf /data/cups/config/printers.conf  /etc/cups/printers.conf
ln -sfn /data/cups/config/ppd           /etc/cups/ppd

# Start CUPS
/usr/sbin/cupsd -f
