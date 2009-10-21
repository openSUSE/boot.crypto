#!/bin/bash
#
#%stage: boot
#

curscript=luks.sh # XXX: to save variables in same config file

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

    save_var root_luks	# do we have luks?
    save_var luks		# which names do the luks devices have?
    save_var cryptmodules	# required kernel modules for crypto setup
    save_var cryptprograms	# keyscripts
    save_var luks_lang	# original language settings
fi
