#!/bin/sh

export easytier_enable="YES"

/usr/local/bin/configctl template reload OPNsense/EasyTier
/usr/local/etc/rc.d/easytier start

# Set up interface group for firewall rules
sleep 3
if ifconfig easytier0 >/dev/null 2>&1; then
    ifconfig easytier0 group easytier 2>/dev/null
fi
