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

if test -t 1 -a "$TERM" != "raw" -a "$TERM" != "dumb"; then
	extd="\e[1m"
	norm="\e[m"
else
	extd=''
	norm=''
fi

luks_check_ply()
{
	if [ -x /usr/bin/plymouth ] && /usr/bin/plymouth --ping; then
		return 0
	fi
	return 1
}

splash_read()
{
	splash=""
	if test -e /proc/splash ; then
		read splash  < /proc/splash
		case "$splash" in
			*silent*) splash='silent' ;;
			*) splash='' ;;
		esac
	fi
}

splash_off()
{
	if ! luks_check_ply && [ -n "$splash" ]; then
		echo verbose > /proc/splash
	fi
}

splash_restore()
{
	if ! luks_check_ply && [ -n "$splash" ]; then
		echo "$splash" > /proc/splash
	fi
}

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
	if luks_check_ply; then
		/usr/bin/plymouth ask-for-password --prompt="Unlocking ${name} ($dev)" | /sbin/cryptsetup --tries=1 luksOpen "$dev" "$name"
	else
		echo -e "${extd}Unlocking ${name} ($dev)${norm}"
		splash_off
		/sbin/cryptsetup --tries=1 luksOpen "$dev" "$name"
	fi
}

check_retry()
{
	# return value != 2 means some error with getting the key,
	# like timeout or ^d. No retry in that case.
	[ "$1" -ne 0 -a "$1" -eq 2 ]
}

do_luks() {
	case $luks_lang in
		en_*|POSIX)
		# We only support english keyboard layout
		;;
		*)
		if luks_check_ply; then
			plymouth display-message --text "Enter your passphrase, only US keyboard layout is supported"
		else
			echo "*** Note: only US keyboard layout is supported."
			echo "*** Please ensure that the password is typed correctly."
		fi
		;;
	esac

	set -- $luks
	if [ $# -gt 1 ]; then
		local reuse_pass=1
	fi

	for luks in "$@"; do
		local pass
		eval local keyfile="\"\${luks_${luks}_keyfile}\""
		eval local keyscript="\"\${luks_${luks}_keyscript}\""
		luks_wait_device "$luks"
		while true; do
			if [ -z "$keyscript" ]; then
				# try to reuse passphrase if multiple
				# devices are to be decrypted
				if [ -n "$reuse_pass" ]; then
					if [ -z "$pass" ]; then
						if luks_check_ply; then
							pass=`/usr/bin/plymouth ask-for-password --prompt="Enter LUKS Passphrase"`
						else splash_off
							echo
							echo -e "${extd}Need to unlock encrypted volumes${norm}"
							echo -n "Enter LUKS Passphrase: "
							read -s pass
							echo
						fi
					fi

					echo "$pass" | luksopen "$luks" "$ask_pass" || {
						pass='xxxxxxxxxxxxxxxxxxxx'; unset pass; luksopen "$luks" "$ask_pass"; }
					check_retry $? || break;
				else
					luksopen "$luks" "$ask_pass"
					check_retry $? || break;
				fi
			else
				$keyscript "$keyfile" | luksopen "$luks" "$ask_pass"
				check_retry $? || break;
			fi
		done
	done

	if [ -n "$pass" ]; then
		pass='xxxxxxxxxxxxxxxxxxxx'
		unset pass
	fi
}

splash_read

do_luks

# Clear the screen of all text
if luks_check_ply; then
	plymouth display-message --text ""
fi

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

# Encrypted volume groups mounted by label or uuid will not
# get recognized otherwise (bnc#722916)
case "$root" in
/dev/disk/by-label/*|/dev/disk/by-uuid/*)
	vgscan
	vgchange -a y
	;;
esac

splash_restore
