#!/bin/bash
# Nuno Silva / RNL (2018)
# Compute a baseline CPU which will be supported by all given hypervisors.

username=root
store_host_caps=true

function virsh_cmd {
	host=$1
	shift
	virsh -c "qemu+ssh://$username@$host/system" "$@"
}


function usage {
	echo "$0 [OPTIONS] [hypervisor...]"
	echo
	echo "Computes/checks a CPU baseline for the given hypervisors. See 'virsh cpu-baseline'."
	echo
	echo "OPTIONS"
	echo "    --compare [cpu-xml]	Run cpu-compare on each given hypervisor using cpu-xml."
	echo "                          Checks whether the hypervisor CPU is capable of providing the"
	echo "                          CPU defined in cpu-xml to a guest."
	echo "    --baseline            Compute a baseline CPU for the given hypervisors."
	echo "                          This is the default option."
	echo "    --gcc                 Get gcc optimizations for each hypervisor"
	exit 1
}


# args: [host...]
function cpu_baseline {
	if ! CAPS_FILE=$(mktemp); then
		exit 1
	fi

	for h in $@; do
		if $store_host_caps; then
			echo "capabilities.$h.xml"
			virsh_cmd $h capabilities | tee capabilities.$h.xml >> $CAPS_FILE
		else
			virsh_cmd $h capabilities >> $CAPS_FILE
		fi
	done


	# does not use the running CPU
	virsh cpu-baseline --features --migratable $CAPS_FILE
	ret=$?
	if test $ret -eq 0; then
		rm $CAPS_FILE
	else
		exit $ret
	fi
}


# args: [host...]
function get_gcc_flags {
	host=$1
	if [[ -z "$host" ]]; then
		echo "gimme a host"
		exit 1
	fi
	# see https://wiki.gentoo.org/wiki/Safe_CFLAGS
	ssh $host -- gcc -v -E -x c -march=native -mtune=native - < /dev/null 2>&1 \
		| grep cc1 \
		| perl -pe 's/ -mno-\S+//g; s/^.* - //g;'
}

function get_hosts_gcc_flags {
	for h in $@; do
		echo " * $h"
		flags="$(get_gcc_flags $h)"
		echo "$flags"
		echo
	done
}
# args: [cpu-file] [host...]
# copy the baseline config to the remote hosts and compare it with their CPU
function cpu_compare {
	test -z "$1$2" && usage
	file=$1
	if ! test -r $file; then
		echo "can't read $file"
		usage
	fi

	shift
	for h in $@; do
		echo "$h"
		# no need to copy the file to the remote host. Virsh is running locally
		# so will look for the file locally.
		virsh_cmd $h cpu-compare $file | ts "+	"
	done
}

if test -z "$1"; then
	usage >&2
fi

if test "$1" = "--compare"; then
	shift
	cpu_compare "$@"
	exit 0
elif test "$1" = "--baseline"; then
	shift
elif test "$1" = "--gcc"; then
	shift
	get_hosts_gcc_flags "$@"
	# TODO: compute common flags (I recommend invoking an external python script)
	exit $?
fi
cpu_baseline "$@"
