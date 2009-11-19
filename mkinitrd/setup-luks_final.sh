#!/bin/bash
#
#%stage: boot
#

curscript=luks.sh # XXX: to save variables in same config file

check_cryptomgr_needed()
{
    local ver=`echo "$kernel_version" | sed  -ne '/^2\.6\.\([0-9]\+\).*/s/^2\.6\.\([0-9]\+\).*/\1/p'`
    if [ -n "$ver" -a -z "${ver//[0-9]}" ] && [ "$ver" -lt 31 ]; then
	: # not needed on < 2.6.31
    else
	cryptmodules="$cryptmodules cryptomgr"
    fi
}

if use_script luks; then
    if [ -n "$root_luks" ]; then
	case "$LANG" in
	    en_*|POSIX)
		# We only support english keyboard layout currently
		;;
	    *)
		echo "Only english keyboard layout supported."
		echo "Please ensure that the password is typed correctly."
		luks_lang="$LANG"
		;;
	esac
	cryptmodules=`sed -ne '/^module/s/.*: //p' < /proc/crypto`
    fi
    
    check_cryptomgr_needed

    save_var root_luks	# do we have luks?
    save_var luks		# which names do the luks devices have?
    save_var cryptmodules	# required kernel modules for crypto setup
    save_var cryptprograms	# keyscripts
    save_var luks_lang	# original language settings
fi
