#!/bin/sh

# Regenerate the configuration template
/usr/local/bin/configctl template reload OPNsense/EasyTier

# Register the EasyTier interface in OPNsense config
/usr/local/bin/configctl interface invoke registration

# Check if EasyTier is enabled in the configuration
ENABLED=$(/usr/local/sbin/pluginctl -g OPNsense.EasyTier.general.enabled 2>/dev/null)

if [ "${ENABLED}" = "1" ]; then
    /usr/local/etc/rc.d/easytier stop 2>/dev/null
    pkill -9 easytier-core 2>/dev/null
    sleep 1
    /usr/local/etc/rc.d/easytier start
    # Wait for TUN interface to come up
    sleep 3
    # Add the fixed easytier0 interface to the easytier group
    if ifconfig easytier0 >/dev/null 2>&1; then
        ifconfig easytier0 group easytier 2>/dev/null
    fi
    # Reload firewall to apply rules
    /usr/local/bin/configctl filter reload
else
    /usr/local/etc/rc.d/easytier stop 2>/dev/null
    pkill -9 easytier-core 2>/dev/null
    ifconfig easytier0 -group easytier 2>/dev/null
    /usr/local/bin/configctl filter reload
fi
