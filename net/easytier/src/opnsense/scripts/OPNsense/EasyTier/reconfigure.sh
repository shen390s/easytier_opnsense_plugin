#!/bin/sh

# Regenerate the configuration template
/usr/local/bin/configctl template reload OPNsense/EasyTier

# Check if EasyTier is enabled in the configuration
ENABLED=$(/usr/local/sbin/pluginctl -g OPNsense.EasyTier.general.enabled 2>/dev/null)

if [ "${ENABLED}" = "1" ]; then
    # Enable and (re)start the service
    /usr/sbin/sysrc easytier_enable=YES 2>/dev/null
    /usr/local/etc/rc.d/easytier restart
else
    # Stop and disable the service
    /usr/local/etc/rc.d/easytier stop 2>/dev/null
    /usr/sbin/sysrc easytier_enable=NO 2>/dev/null
fi
