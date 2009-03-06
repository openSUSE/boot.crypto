#!/bin/bash
#
#%stage: crypto
#

# search for entries that have the 'initrd' option set
find_crypttab_initrd()
{
    test -s /etc/crypttab || return

    local addit extraopts

    while read name physdev keyfile options dummy; do
	case "$name" in
	\#*|"") continue ;;
	esac
	if [ "$keyfile" != "none" ]; then
	    echo "/etc/crypttab: $name: keyfile not supported by the initrd"
	    continue
	fi
	if [ "$options" = "none" ]; then
	    continue
	fi

	addit=''
	extraopts=''

	IFS=, eval set -- $options
	for param in "$@"; do
	    case "$param" in
	    luks) ;;
	    initrd) addit=1 ;;
	    *) extraopts=1 ;;
	    esac
	done

	if [ -n "$addit" ]; then
	    if [ -n "$extraopts" ]; then
		echo "/etc/crypttab: $name has extra options, not supported by the initrd"
	    else
		luks_add_device="$luks_add_device /dev/mapper/$name"
	    fi
	fi
    done < /etc/crypttab
}

if [ -x /sbin/cryptsetup -a -x /sbin/dmsetup ] ; then
    luks_blockdev=
    luks_add_device="$blockdev"
    find_crypttab_initrd
    # bd holds the device we see the decrypted LUKS partition as
    for bd in $luks_add_device ; do
    	luks_name=
	update_blockdev $bd
	luks_blockmajor=$blockmajor
	luks_blockminor=$blockminor
	# luksbd holds the device, LUKS is running on
	for luksbd in $(dm_resolvedeps $bd); do # should only be one for luks
		[ $? -eq 0 ] || return 1
		update_blockdev $luksbd
		if /sbin/cryptsetup isLuks $luksbd 2>/dev/null; then
			root_luks=1
			tmp_root_dm=1 # luks needs dm

			luks_name="$(dmsetup -c info -o name --noheadings -j $luks_blockmajor -m $luks_blockminor)"
			eval luks_${luks_name}=$(beautify_blockdev ${luksbd})
			save_var luks_${luks_name}

			luks="$luks $luks_name"
			echo "enabling LUKS support for $luksbd"
			luks_blockdev="$luks_blockdev $luksbd"
		fi
	done
	if [ ! "$luks_name" ]; then # no luks found
		luks_blockdev="$luks_blockdev $bd"
	fi
    done
    blockdev="$luks_blockdev"
fi

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
save_var luks_lang	# original language settings
