#!/bin/bash
#
#%stage: crypto
#

dbg()
{
    test -n "$mkinitrd_luks_debug" || return 0
    echo "$@"
}

# search for entries that have the 'initrd' option set
find_crypttab_initrd()
{
    luks_add_device=()
    test -s /etc/crypttab || return

    local addit extraopts
    local name physdev keyfile options dummy

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

	IFS=, eval set -- \$options
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
		luks_add_device+=("/dev/mapper/$name")
	    fi
	fi
    done < /etc/crypttab
}

isset()
{
    eval "test -n \"\$$1\""
}

find_luks_devices()
{
    luks_blockdev=
    # bd holds the device we see the decrypted LUKS partition as
    for bd in "${luks_add_device[@]}" $blockdev; do
    	luks_name=
	update_blockdev $bd
	luks_blockmajor=$blockmajor
	luks_blockminor=$blockminor
	dbg "finding deps of $bd ($blockmajor:$blockminor) ..."
	deps=$(dm_resolvedeps $bd)
	# luksbd holds the device, LUKS is running on
	for luksbd in $deps; do # should be only one for luks
	    update_blockdev $luksbd
	    dbg -n "isLuks $luksbd ... "
	    if ! /sbin/cryptsetup isLuks $luksbd 2>/dev/null; then
		dbg "no"
		continue
	    fi
	    dbg "yes"
	    root_luks=1
	    tmp_root_dm=1 # luks needs dm

	    luks_name="$(dmsetup -c info -o name --noheadings -j $luks_blockmajor -m $luks_blockminor)"
	    if isset "luks_${luks_name}"; then
		dbg "$luks_name already handled"
		continue
	    fi
	    eval luks_${luks_name}=$(beautify_blockdev ${luksbd}) || continue
	    save_var luks_${luks_name}
	    ! isset luks_${luks_name}_options || save_var luks_${luks_name}_options

	    luks="$luks $luks_name"
	    echo "enabling LUKS support for $luksbd ($luks_name)"
	    luks_blockdev="$luks_blockdev $luksbd"
	done
	if [ ! "$luks_name" ]; then # no luks found
	    luks_blockdev="$luks_blockdev $bd"
	fi
    done
    blockdev="$luks_blockdev"
}

find_crypttab_initrd
unset luks_add_device

find_luks_devices
