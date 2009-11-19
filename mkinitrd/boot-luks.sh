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

# can't do this in luksopen as it would mix output with the
# keyscript
luks_wait_device()
{
	local name="$1"
	eval local dev="\"\${luks_${luks}}\""
	check_for_device "$dev"
}

luksopen()
{
	local name="$1"
	eval local dev="\"\${luks_${luks}}\""
	/sbin/cryptsetup --tries=1 luksOpen "$dev" "$name"
}

check_retry()
{
	# return value != 255 means some error with getting the key,
	# like timeout or ^d. No retry in that case.
	[ "$1" -ne 0 -a "$1" -eq 255 ]
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
		luks_wait_device "$luks"
		while true; do
			if [ -z "$keyscript" ]; then
				# try to reuse passphrase if multiple
				# devices are to be decrypted
				if [ -n "$reuse_pass" ]; then
					if [ -z "$pass" ]; then
						local pass
						echo
						echo -n "Enter LUKS Passphrase: "
						read -s pass
						echo
					fi

					echo "$pass" | luksopen "$luks" || {
						pass='xxxxxxxxxxxxxxxxxxxx'; unset pass; luksopen "$luks"; }
					check_retry $? || break;
				else
					luksopen "$luks"
					check_retry $? || break;
				fi
			else
				$keyscript "$keyfile" | luksopen "$luks"
				check_retry $? || break;
			fi
		done
	done

	if [ -n "$pass" ]; then
		pass='xxxxxxxxxxxxxxxxxxxx'
		unset pass
	fi
}

do_luks

# XXX: activate and wait for volume groups if the resume volume is
# on lvm. This is a layering violation but with current mkinitrd
# design we have no other choice if we want to resume from a vg
# inside luks.
if [ -n "$vg_resume" ]; then
	for vgr in $vg_root $vg_resume $vg_roots; do
		vgchange -a y $vgr
	done
	wait_for_events
fi
