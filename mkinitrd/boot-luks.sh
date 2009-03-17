#!/bin/bash
#%stage: crypto
#%programs: /sbin/cryptsetup
#%udevmodules: dm-crypt $cryptmodules
#%if: "$root_luks" -o "$luks"
#
##### LUKS (comfortable disk encryption)
##
## This activates a LUKS encrypted partition.
##
## Command line parameters
## -----------------------
##
## luks			a list of luks devices (e.g. xxx)
## luks_xxx		the luks device (e.g. /dev/sda)
## 

luksopen()
{
	local dev="$1"
	eval /sbin/cryptsetup luksOpen "\"\${luks_${luks}}\"" "\"\$dev\""
}

do_luks() {
	case $luks_lang in
		en_*|POSIX)
		# We only support english keyboard layout
		;;
		*)
		echo "Only english keyboard layout supported."
		echo "Please ensure that the password is typed correctly."
		;;
	esac

	set -- $luks

	# try to reuse passphrase if multiple devices are to be
	# decrypted
	if [ $# -gt 1 ]; then
		local pass
		echo
		echo -n "Enter LUKS Passphrase:"
		read -s pass
		echo

		for luks in "$@"; do
			echo $pass | luksopen "$luks" || luksopen "$luks"
		done

		pass='xxxxxxxxxxxxxxxxxxxx'
		unset pass
	else
		luksopen "$luks"
	fi
}

do_luks
