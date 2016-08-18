#!/bin/bash
# Script para criar VMs baseadas no template de Gentoo hardened x86_64
# André Aparício (2013)

# bash "strict mode"
#set -euo pipefail
#IFS=$'\n\t'
# allows patterns which match no files to expand to a null string, rather than themselves
shopt -s nullglob

### DEFAULTS ###

MAX_NUM_CPU=8
DEFAULT_RAM_SIZE="256MiB"
DEFAULT_NUM_CPU=1
DEFAULT_DISK_SIZE="5" # GB

### Hardcoded stuff ###

DISK_LOCATION="/var/lib/libvirt/images"
LIB_LOCATION="/usr/libexec/vm-scripts/lib"
LIB_SCRIPTS="lib/*.sh /usr/local/libexec/vm-scripts/lib/*.sh /usr/libexec/vm-scripts/lib/*.sh"
TEMPLATES_LOCATION="/usr/libexec/vm-scripts/templates"
XML_TEMPLATE="/usr/rnl-overlay/stage4/neo.xml"
NEWVM_MOUNTPOINT="/mnt/newvm"

### Parse argumetns ###

for arg in $@; do
	case $arg in
		debug)
			DEBUG=1
			;;
		dry-run)
			DRYRUN=1
			;;
		*)
			echo "Usage: $0 [debug] [dry-run]"
			exit
			;;
	esac
done

### Include other files ###

for file in ${LIB_SCRIPTS}; do
	source $file
done

### MAIN ###

echo "Answer the details below so that I can configure the VM and change the disk image to match the details provided."
echo "Only after answering and confirming everything the actual actions will be executed."
echo

set_name

ask_network_settings

ask_storage_settings

prompt "Amount of RAM to use?" RAM_SIZE $DEFAULT_RAM_SIZE

prompt "Number of CPUs?" NUM_CPU $DEFAULT_NUM_CPU

prompt "\nExecute?" COSTUMIZE Y

[[ $COSTUMIZE = [yY] ]] || exit

echo -e "Executing...\n"

virsh_define_vm $NAME $ROOT_DISK_TYPE $ROOT_DISK_LOCATION

if [[ $ROOT_DISK_TYPE == "none" ]]; then
	echo "VM configured without storage, good luck with that now..."
	exit
fi

### Create the new root disk image ###

case $ROOT_DISK_WRITE in # case switch with intentional fall throughs

	all)
		case $ROOT_DISK_TYPE in
			file)
				create_disk_file $ROOT_DISK_LOCATION $ROOT_DISK_SIZE
				;;
			lvm)
				create_disk_lvm $NAME $ROOT_DISK_SIZE
				;;
		esac
		;& # fall through

	format)
		format_disk $ROOT_DISK_LOCATION $NAME
		;& # fall through

	populate)
		mount_disk $ROOT_DISK_LOCATION $NEWVM_MOUNTPOINT

		case $ROOT_DISK_FS_ACTION in
			template)
				extract_template $ROOT_DISK_FS_TEMPLATE $NEWVM_MOUNTPOINT
				;;
			tarball)
				extract_template $ROOT_DISK_FS_TEMPLATE $NEWVM_MOUNTPOINT
				;;
			copy_vm)
				echo "Copying VM"
				;;
			none)
				echo "Leaving filesystem empty"
				;;
		esac
		;& # fall through

	customize)
		if ! is_mounted $NEWVM_MOUNTPOINT; then
			mount_disk $ROOT_DISK_LOCATION $NEWVM_MOUNTPOINT
		fi

		if [[ $ROOT_DISK_FS_TEMPLATE_OS != 'none' ]]; then
			customize_disk
		else
			guess_script_template $NEWVM_MOUNTPOINT
		fi

		umount_disk $NEWVM_MOUNTPOINT
		;;  # do not fall through

	none)
		echo "Not touching existing disk"
esac

echo "Profit!"
echo "Run \"virsh start $NAME\" to start the VM. Or don't, whatever."
