#! /bin/bash
# Nuno Silva / RNL / 2018


### Hardcoded stuff ###
LIB_LOCATION="/usr/libexec/vm-scripts/lib"
LIB_SCRIPTS="lib/*.sh /usr/local/libexec/vm-scripts/lib/*.sh $LIB_LOCATION/*.sh"

### Include other files ###
for file in ${LIB_SCRIPTS}; do
	test -r $file && source $file
done

### functions ###
# args: <vm> <key>
function send_key {
	vm=$1
	key=${2^^} # uppercase
	info "Sending sysrq $key"
	$pretend virsh_send_key $vm KEY_LEFTALT KEY_SYSRQ KEY_$key
}

# args: <vm> <key>
function do_combination {
	error "COMBINATIONS not implemented. Use a single KEY :/"
	exit 1
}

function print_usage {
	cat >&2 <<EOM
Usage: vm-sysrq <vm> <KEY|COMBINATION>

	Send a sysrq key or keys to a running VM.

COMBINATIONS

	The following sysrq key combinations are available:

	reisub

KEYS

	Available sysrq keys are:

	loglevel(0-9)
	reboot(b)
	crash(c)
	terminate-all-tasks(e)
	memory-full-oom-kill(f)
	help(h)
	kill-all-tasks(i)
	thaw-filesystems(j)
	sak(k)
	show-backtrace-all-active-cpus(l)
	show-memory-usage(m)
	nice-all-RT-tasks(n)
	poweroff(o)
	show-registers(p)
	show-all-timers(q)
	unraw(r)
	sync(s)
	show-task-states(t)
	unmount(u)
	force-fb(V)
	show-blocked-tasks(w)
EOM
}

# args: <key>
function is_key_valid {
	# list of valid keys
	KEYS="0123456789bcefhijklmnopqrstuvw"
	KEYS=${KEYS^^}
	key=${1^^}
	test ${#key} -eq 1 && [[ "$KEYS" = *"$key"* ]]
}

### main ###

if test $# -lt 2; then
	print_usage
	exit 1
fi

host=$1
key=$2
if test ${#key} -eq 1; then
	if is_key_valid $key; then
		prompt "\nSend SYSRQ key $key? This might be dangerous." CONTINUE Y
		[[ $CONTINUE = [yY] ]] && send_key $host $key
	else
		error "invalid key: $key"
		print_usage
		exit 1
	fi
else
	do_combination $host $key
fi
