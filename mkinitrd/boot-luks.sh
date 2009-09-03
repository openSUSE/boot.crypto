#!/bin/bash
#%stage: crypto
#%programs: /sbin/cryptsetup $cryptprograms
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
	local name="$1"
	eval local dev="\"\${luks_${luks}}\""
	check_for_device "$dev"
	/sbin/cryptsetup --tries=1 luksOpen "$dev" "$name"
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
	if [ $# -gt 1 ]; then
		local reuse_pass=1
	fi

	for luks in "$@"; do
		eval local keyfile="\"\${luks_${luks}_keyfile}\""
		eval local keyscript="\"\${luks_${luks}_keyscript}\""
		if [ -z "$keyscript" ]; then
			# try to reuse passphrase if multiple
			# devices are to be decrypted
			if [ -n "$reuse_pass" ]; then
				if [ -z "$pass" ]; then
					local pass
					echo
					echo -n "Enter LUKS Passphrase:"
					read -s pass
					echo
				fi

				echo "$pass" | luksopen "$luks" || {
					pass='xxxxxxxxxxxxxxxxxxxx'; unset pass; luksopen "$luks"; }
			else
				luksopen "$luks"
			fi
		else
			$keyscript "$keyfile" | luksopen "$luks"
		fi

	done

	if [ -n "$pass" ]; then
		pass='xxxxxxxxxxxxxxxxxxxx'
		unset pass
	fi
}

do_luks
