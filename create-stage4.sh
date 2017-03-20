#!/bin/bash

EXCLUDE="
./swapfile
./root/.vim_tmp/*
./root/.viminfo
./root/.ansible
./root/.ssh/known_hosts
./root/.rnd
./root/.bash_history
./etc/ssh/ssh_host_*
./etc/config-archive/*
./var/lib/cdist
./var/log/*
./tmp/*
./lost+found/*
"
# allows patterns which match no files to expand to a null string, rather than themselves
shopt -s nullglob

LIB_SCRIPTS="lib/*.sh /usr/local/libexec/vm-scripts/lib/*.sh /usr/libexec/vm-scripts/lib/*.sh"

### Include other files ###
for file in ${LIB_SCRIPTS}; do
	source $file
done

function tar_cmd {
	echo "tar cjf - --totals=USR1 --one-file-system --exclude-backups --exclude-from=- -C $1 ."
}

function progress_signal {
	echo "sleep 1; while pgrep tar; do pkill -USR1 tar; sleep 5; done"
}

function virsh_vm_exists() {
	which virsh &>/dev/null || return 1
	virsh -c qemu:///system dominfo $1 &>/dev/null
}

function virsh_vm_is_running() {
	virsh -c qemu:///system dominfo $1 | grep "^State:[ ]*running" >/dev/null
}

function virsh_disk_location() {
	virsh -c qemu:///system domblklist $1 | awk '$1 == "vda" {print $2}'
}

function process_directory() {
	local tarball=$1
	local directory=$2

	if [ ! -d "$directory" ]; then
		echo "$directory is not a valid directory"

	elif [ ! -x "${directory}/sbin/init" ]; then
		echo "${directory}/sbin/init not found. Are you sure this is a valid root filesystem? Maybe you forget to mount it?"

	else
		echo "Building stage4 from local directory $directory (this may take a while)"
		eval $(progress_signal) >/dev/null &
		echo "$EXCLUDE" | $(tar_cmd $directory) > "$tarball"
		echo "Done"
	fi
}

function process_ssh() {
	local tarball=$1
	local host=$2

	echo "Building stage4 from remote host $host (this may take a while)"

	local ssh_socket=~/.ssh/create-stage4-socket

	# Creates a multiplexed SSH connection to only ask the password once
	ssh -S $ssh_socket -M -o ControlPersist=10m -o ConnectTimeout=3 $host true

	[[ $? != 0 ]] && return

	ssh -S $ssh_socket $host "$(progress_signal $host)" >/dev/null &
	echo "$EXCLUDE" | ssh -S $ssh_socket $host "$(tar_cmd /)" > "$tarball"

	# Terminates the master connection
	ssh -S $ssh_socket -O stop $host 2>/dev/null
	echo "Done"
}

function process_vm() {
	local tarball=$1
	local name=$2

	if virsh_vm_is_running $name; then

		echo "The VM seems to be running."
		prompt "Do you want me to shut it down and create the tarball from a mounted directory?" ANWSER Y

		[[ $ANWSER = [yY] ]] || return

		virsh shutdown $name &>/dev/null

		echo "Waiting for the VM to shutdown (60 seconds max)..."

		local count=0
		while virsh_vm_is_running $name && [[ $count < 60 ]]; do
			sleep 1
			count=$((count + 1))
		done

		if virsh_vm_is_running $name; then
			warning "The VM doesn't seem to have shutdown, go see what is the problem."
			return
		fi

		echo "VM turned off"
	else
		echo "VM already turned off"
	fi

	local disk_location=$(virsh_disk_location $name)
	local mountpoint=/mnt/stage4_tmp

	mount_disk $disk_location $mountpoint

	process_directory $tarball $mountpoint

	umount_disk $mountpoint
}


FILE=$1
LOCATION=$2

if [ -z $LOCATION ]; then
	echo "Usage: $0 <destination file> ( <local path> | <VM name> | <hostname> )"
	exit
fi

# Tries to guess the type of action necessary by the location/name given

case $LOCATION in

	# If the location has a slash it must be a local directory
	*/*)
		process_directory $FILE $LOCATION
		;;

	# If the location has a '@' it must be to connect with SSH
	*@*)
		process_ssh $FILE $LOCATION
		;;

	*)
		# Checks if the location is an existing directory
		if [ -d $LOCATION ]; then
			process_directory $FILE $LOCATION

		# Checks if it matches the name of an existing VM on the current host
		elif virsh_vm_exists $LOCATION; then
			process_vm $FILE $LOCATION

		# If all fails, check if it matches a DNS name, to try with SSH
		elif host $LOCATION &>/dev/null; then
			process_ssh $FILE $LOCATION

		else
			warning "$LOCATION does not seem to be a valid path or machine."
		fi
esac
