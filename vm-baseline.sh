#!/bin/bash
# Nuno Silva / RNL (2018)
# Compute a baseline CPU which will be supported by all given hypervisors.

username=root

function virsh_cmd {
	host=$1
	shift
	virsh -c "qemu+ssh://$username@$host/system" "$@"
}


function usage {
	echo "$0 [hypervisor...]"
	echo
	echo "Computes a CPU baseline for the given hypervisors. See 'virsh cpu-baseline'."
	exit 1
}

if test -z "$1"; then
	usage >&2
fi


if ! CAPS_FILE=$(mktemp); then
	exit 1
fi

for h in $@; do
	virsh_cmd $h capabilities >> $CAPS_FILE
done


# does not use the running CPU
virsh cpu-baseline --features --migratable $CAPS_FILE
ret=$?
if test $ret -eq 0; then
	rm $CAPS_FILE
else
	exit $ret
fi
