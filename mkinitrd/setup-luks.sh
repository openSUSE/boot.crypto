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

    local addit extraopts keyscript
    local name physdev keyfile options dummy

    while read name physdev keyfile options dummy; do
	case "$name" in
	\#*|"") continue ;;
	esac

	[ "$keyfile" != "none" ] || keyfile=''
	[ "$options" != "none" ] || continue

	addit=''
	extraopts=''
	keyscript=''

	IFS=, eval set -- \$options
	for param in "$@"; do
	    case "$param" in
	    luks) ;;
	    initrd) addit=1 ;;
	    keyscript=*) keyscript="${param#*=}" ;;
	    *) extraopts=1 ;;
	    esac
	done

	[ -n "$addit" ] || continue

	if [ -n "$extraopts" ]; then
	    echo "/etc/crypttab: $name has extra options, not supported by the initrd" >&2
	    continue;
	elif [ -n "$keyscript" ]; then
	    if [ "${keyscript:0:1}" != '/' ]; then
		keyscript="/lib/cryptsetup/scripts/$keyscript"
	    fi
	    if [ ! -x "$keyscript" ]; then
		echo "keyscript \"$keyscript\" must be an executable" >&2
		continue
	    fi
	    eval "luks_${name}_device=\"\$physdev\""
	    eval "luks_${name}_keyscript=\"\$keyscript\""
	    [ -z "$keyfile" ] || eval "luks_${name}_keyfile=\"\$keyfile\""
	    eval "luks_${name}_options=\"\$options\""
	elif [ -n "$keyfile" ]; then
	    echo "/etc/crypttab: $name: keyfile not supported by the initrd" >&2
	    continue
	fi
	luks_add_device+=("/dev/mapper/$name")
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
	if [ "$blockdriver" != "device-mapper" ]; then
	    luks_blockdev="$luks_blockdev $bd"
	    continue
	fi
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
	    save_var luks_${luks_name}_device
	    ! isset luks_${luks_name}_options || save_var luks_${luks_name}_options
	    ! isset luks_${luks_name}_keyfile || save_var luks_${luks_name}_keyfile
	    if isset luks_${luks_name}_keyscript; then
		save_var luks_${luks_name}_keyscript
		eval "keyscript=\"\$luks_${luks_name}_keyscript\""
		cryptprograms="$cryptprograms $keyscript"
		# hack as setup-progs.sh does not create directories (bnc#536470)
		mkdir -p $tmp_mnt${keyscript%/*}
	    fi

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
find_luks_devices
unset luks_add_device
