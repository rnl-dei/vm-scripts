#!/bin/bash
# Script para criar VMs baseadas no template de Gentoo hardened x86_64
# André Aparício (2013)

### DEFAULTS ###

MAX_NUM_CPU=8
DEFAULT_RAM_SIZE="256MiB"
DEFAULT_NUM_CPU=1
DEFAULT_DISK_SIZE="5"

### Hardcoded stuff ###

DISK_LOCATION="/var/lib/libvirt/images"
LIB_LOCATION="/root/vm-scripts/lib"
TEMPLATE_VM="neo"
TEMPLATE_MOUNTPOINT="/mnt/template"
NEWVM_MOUNTPOINT="/mnt/newvm"

for file in ${LIB_LOCATION}/*.sh; do
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
echo -e "Executing...\n"

virsh_define_vm $NAME $ROOT_DISK_TYPE $ROOT_DISK_LOCATION

if [[ $ROOT_DISK_TYPE == "none" ]]; then
	echo "VM configured without storage, good luck with that now..."
	exit
fi

### Create the new root disk image ###

case $ROOT_DISK_TYPE in
	file)
		create_disk_file $ROOT_DISK_LOCATION $ROOT_DISK_SIZE
		;;
	lvm)
		create_disk_lvm $NAME $ROOT_DISK_SIZE
		;;
esac

if [ $ROOT_DISK_WRITE ]; then

	format_disk $ROOT_DISK_LOCATION $NAME

	mount_disk $ROOT_DISK_LOCATION $NEWVM_MOUNTPOINT

	case $ROOT_DISK_FS_ACTION in
		template)
			extract_template $ROOT_DISK_FS_TEMPLATE $NEWVM_MOUNTPOINT
			customize_disk
			;;
		tarball)
			extract_template $ROOT_DISK_FS_TEMPLATE $NEWVM_MOUNTPOINT
			guess_script_template $NEWVM_MOUNTPOINT
			;;
		copy_vm)
			echo "Copying VM"
			guess_script_template $NEWVM_MOUNTPOINT
			;;
		none)
			echo "Formating filesystem and leaving it empty"
			;;
	esac

	echo umount_disk $NEWVM_MOUNTPOINT
else
	echo "Not formating existing disk"
fi

echo "Profit!"
echo "Run \"virsh start $NAME\" to start the VM."
