#!/bin/bash
#
#%stage: volumemanager
#%depends: lvm2
#

curscript=luks.sh # XXX: to save variables in same config file

if use_script lvm2; then
    find_luks_devices
fi
