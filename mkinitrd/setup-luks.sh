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
	elif [ -z "$keyscript" -a -n "$keyfile" ]; then
	    echo "/etc/crypttab: $name: keyfile not supported by the initrd" >&2
	    continue
	else
	    dbg "got $name ($physdev) from crypttab"
	    varname=${name//[^a-zA-Z0-9_]/_}
	    eval "luks_${varname}_device=\"\$physdev\""
	    if [ -n "$keyscript" ]; then
		if [ "${keyscript:0:1}" != '/' ]; then
		    keyscript="/lib/cryptsetup/scripts/$keyscript"
		fi
		if [ ! -x "$keyscript" ]; then
		    echo "keyscript \"$keyscript\" must be an executable" >&2
		    continue
		fi
		eval "luks_${varname}_keyscript=\"\$keyscript\""
		[ -z "$keyfile" ] || eval "luks_${varname}_keyfile=\"\$keyfile\""
		eval "luks_${varname}_options=\"\$options\""
	    fi
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
	luks_physdev=
	varname=
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
	    if ! /usr/sbin/cryptsetup isLuks $luksbd 2>/dev/null; then
		dbg "no"
		continue
	    fi
	    dbg "yes"
	    root_luks=1
	    tmp_root_dm=1 # luks needs dm

	    luks_name="$(dmsetup -c info -o name --noheadings -j $luks_blockmajor -m $luks_blockminor)"
	    varname=${luks_name//[^a-zA-Z0-9_]/_}
	    if isset "luks_${varname}"; then
		dbg "$luks_name already handled"
		continue
	    fi
	    dbg "found name $luks_name"
	    if isset "luks_${varname}_device"; then
		    eval luks_physdev=\$luks_${varname}_device
	    fi
	    if [ -z "$luks_physdev" ]; then
		eval luks_physdev=$(beautify_blockdev ${luksbd}) || continue
	    fi
	    eval luks_${varname}=\"\$luks_physdev\"
	    eval luks_${varname}_name=\"\$luks_name\"
	    save_var luks_${varname}
	    save_var luks_${varname}_device
	    save_var luks_${varname}_name
	    ! isset luks_${varname}_options || save_var luks_${varname}_options
	    ! isset luks_${varname}_keyfile || save_var luks_${varname}_keyfile
	    if isset luks_${varname}_keyscript; then
		save_var luks_${varname}_keyscript
		eval "keyscript=\"\$luks_${varname}_keyscript\""
		cryptprograms="$cryptprograms $keyscript"
		# hack as setup-progs.sh does not create directories (bnc#536470)
		mkdir -p $tmp_mnt${keyscript%/*}
	    fi

	    luks="$luks $varname"
	    echo "enabling LUKS support for ${luks_physdev} ($luks_name)"
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
