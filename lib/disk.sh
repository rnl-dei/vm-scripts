function get_disk_type() {
	local disk_type_var=$1 disk_location_var=$2 disk_write_var=$3
	local disk_type=none disk_location= disk_write=true

	echo "Disk options:"
	echo "  1 - Use a file (in /var/lib/libvirt/images/)."
	echo "  2 - Use a LVM logical volume"
	echo "  3 - Do not configure any disk."
	echo "  0 - Flip the table."

	prompt "?" OPTION 1
	case $OPTION in
		1)
			disk_type=file
			disk_location=${DISK_LOCATION}/${NAME}.img
			;;
		2)
			disk_type=lvm
			disk_location=/dev/vg0/$NAME
			;;
		3)
			disk_type=none
			disk_location=none
			;;
		0)
			echo "Bye bye..."
			exit
			;;
	esac

	if [[ $disk_location != "none" ]]; then
		local disk_name=$NAME
		disk_write=all

		if [ -a "$disk_location" ]; then
			local size=$(file_human_size $disk_location)
			warning "A disk file with the name $disk_name.img already exists! ($size)"
			echo "What do you want to do?"
			echo "  1 - Choose a different name for the VM."
			echo "  2 - Use the existing disk without touching it (WARNING: The MAC address on /etc/udev/rules.d/ will need an update)"
			echo "  3 - Use the existing disk and customize it"
			echo "  4 - Overwrite the existing disk (keeps the same size)"
			echo "  5 - Remove and create a new disk"
			echo "  0 - Flip the table."

			prompt "?" OPTION
			case $OPTION in
				1)
					while [ -a "$disk_location" ]; do
						prompt "Type the new disk name: " disk_name
						disk_location=$DISK_LOCATION/$DISK_NAME.img
					done
					;;
				2)
					disk_write=none
					;;
				3)
					disk_write=customize
					;;
				4)
					disk_write=format
					;;
				5)
					disk_write=all
					warning "NOT TESTED BYE"
					exit
					;;
				0)
					echo "Bye bye..."
					exit
					;;
				*)
					disk_write=none
					;;
			esac
		fi
	fi

	eval $disk_type_var=$disk_type
	eval $disk_location_var=$disk_location
	eval $disk_write_var=$disk_write
}


function get_disk_fs_action() {
	local fs_action_var=$1 fs_template_var=$2 fs_template_os_var=$3 fs_template_script_var=$4
	local fs_action=none fs_template=none fs_template_os=none fs_template_script=none

	echo "What do you want to do with the disk?"
	echo "  1 - Use one of the templates"
	echo "  2 - Select a tarball manually"
	echo "  3 - Copy an existing VM"
	echo "  4 - Leave the disk empty"
	echo "  0 - Flip the table."

	prompt "?" OPTION 1

	case "$OPTION" in
		1) # Template
			get_os_template OS_TEMPLATE

			fs_template_script=${TEMPLATES_LOCATION}/os?_${OS_TEMPLATE}.sh

			if [ ! -f $fs_template_script ]; then
				warning "Could not find $fs_template_script for some reason"
				exit
			fi

			source $fs_template_script

			if [ -z $STAGE4_FILE ]; then
				warning "The STAGE4_FILE variable is not defined in $fs_template_script"
				exit
			fi

			if [ ! -f $STAGE4_FILE ]; then
				warning "The base image file $STAGE4_FILE defined in $fs_template_script doest not exist"
				exit
			fi
			fs_action=template
			fs_template=$STAGE4_FILE
			fs_template_os=$OS_TEMPLATE
			;;
		2) # Select tarball
			FS_TEMPLATE=none
			while [ ! -f "$FS_TEMPLATE" ]; do
				prompt "Tarball path: " FS_TEMPLATE
			done
			fs_action=tarball
			fs_template=$FS_TEMPLATE
			fs_template_os=none
			;;
		3) # Copy VM
			FS_TEMPLATE=none
			while ! virsh_name_exist "$FS_TEMPLATE"; do
				prompt "VM name: " FS_TEMPLATE
			done
			fs_action=copy_vm
			fs_template=$FS_TEMPLATE
			fs_template_os=none
			;;
		4) # Empty
			fs_action=none
			fs_template=none
			fs_template_os=none
			;;
		0)
			echo "Bye bye..."
			exit
			;;
	esac

	eval "${fs_action_var}=${fs_action}"
	eval "${fs_template_var}=${fs_template}"
	eval "${fs_template_os_var}=${fs_template_os}"
	eval "${fs_template_script_var}=${fs_template_script}"
}

function get_os_template() {
	local os_template_var=$1
	local os_template=none

	local os_scripts=${TEMPLATES_LOCATION}/os?_*.sh
	echo "What template do you want to use?"

	local i=1
	local options
	declare -a options

	for file in ${os_scripts}; do
		os=$(basename $file .sh)
		os=${os#os?_}
		options[i]="${os}"
		echo "  $((i++)) - $os"
	done

	options[i]="exit"
	echo "  0 - Flip the table."

	prompt "?" OPTION 1

	os_template="${options[$OPTION]}"

	eval $os_template_var=$os_template
}


function guess_script_template() {
	local mountpoint=$1

	local os=$(awk -F '=' '/ID/{print $2}' ${mountpoint}/etc/os-release)
	local os_script=${TEMPLATES_LOCATION}/os?_${os}.sh

	echo "The new VM seems to have a ${os} filesystem."
	prompt "Do you want to costumize it with the script ${os_script}?" CUSTOMIZE Y

	if [[ $CUSTOMIZE == [yY] ]]; then
		source $os_script
		customize_disk
	fi
}

function create_disk_file() {
	local file=$1
	local size=$2
	echo "Creating the disk in $file with $size GB, this may take a while..."
	dd if=/dev/zero of=$file bs=1M count=$((size * 1000)) 2>&1 | quote_output
}

function create_disk_lvm() {
	echo "Creating the LVM partition"
	local name=$1
	local size=$2
	lvcreate -L ${size}G -n "$name" vg0 | quote_output
}

function format_disk() {
	local path=$1
	local name=$2
	echo "Formating $path to ext4..."
	mkfs.ext4 -F -E nodiscard -L "${name}_root" $path 2>&1 | quote_output
}

function file_human_size() {
	ls -l --block-size=G $1 | awk '{print $5}'
}

function is_mounted() {
	local mountpoint=$1
	mount | grep $mountpoint >/dev/null
}

function mount_disk() {
	local file=$1
	local mountpoint=$2
	echo "Mounting $file in $mountpoint"
	mkdir -p $mountpoint
	mount -o loop $file $mountpoint
}

function umount_disk() {
	local mountpoint=$1
	echo "Unmounting $mountpoint"
	umount $mountpoint
	rmdir $mountpoint
}

function extract_template () {
	local file=$1
	local mountpoint=$2
	echo "Extracting $file to $mountpoint, this may take a while..."
	#echo rsync --archive --numeric-ids $TEMPLATE_MOUNTPOINT/ $NEWVM_MOUNTPOINT --exclude='/var/log/' --exclude='/etc/ssh/ssh_host*'
	tar xf $file -C $mountpoint
}

function check_storage_config() {

	echo "Storage configuration to be executed:"

	if [[ $ROOT_DISK_TYPE == "none" ]]; then
		info "No storage configured" 
		return
	fi

	case $ROOT_DISK_WRITE in

		all)
			case $ROOT_DISK_TYPE in
				file)
					info "Create disk on file $ROOT_DISK_LOCATION with $ROOT_DISK_SIZE GB"
					;;
				lvm)
					info "Create disk on LVM logical volume $ROOT_DISK_LOCATION with $ROOT_DISK_SIZE GB"
					;;
				*)
					info "Shit happened at line $LINENO in disk.sh"
					;;
			esac
			;&

		format)
			info "Format $ROOT_DISK_LOCATION with ext4"
			;&

		populate)

			case $ROOT_DISK_FS_ACTION in
				template)
					info "Extract $ROOT_DISK_FS_TEMPLATE_OS tarball from $ROOT_DISK_FS_TEMPLATE"
					;;
				tarball)
					info "Extract tarball from $ROOT_DISK_FS_TEMPLATE"
					;;
				copy_vm)
					info "Copy filesystem from VM $ROOT_DISK_FS_TEMPLATE"
					;;
				none)
					info "Leave filesystem empty"
					;;
			esac
			;&

		customize)
			if [[ $ROOT_DISK_FS_TEMPLATE_OS != 'none' ]]; then
				info "Execute $ROOT_DISK_FS_TEMPLATE_OS costumization script $ROOT_DISK_FS_TEMPLATE_SCRIPT"
			else
				info "Try to guess existing disk OS to execute customization scripts"
			fi
			;;

		none)
			info "  Do not touch existing disk"
	esac
}

function ask_storage_settings {
	STORAGE_OK="n"
	while [[ $STORAGE_OK == "n" ]]; do

		get_disk_type ROOT_DISK_TYPE ROOT_DISK_LOCATION ROOT_DISK_WRITE

		ROOT_DISK_FS_ACTION=none
		ROOT_DISK_FS_TEMPLATE=none
		ROOT_DISK_FS_TEMPLATE_OS=none
		ROOT_DISK_FS_TEMPLATE_SCRIPT=none

		case $ROOT_DISK_WRITE in
			all)
				prompt "Size of the root disk image in GB (the base system requires at least 1Gb)?" ROOT_DISK_SIZE $DEFAULT_DISK_SIZE
				;&
			format)
				;&
			populate)
				get_disk_fs_action ROOT_DISK_FS_ACTION ROOT_DISK_FS_TEMPLATE ROOT_DISK_FS_TEMPLATE_OS ROOT_DISK_FS_TEMPLATE_SCRIPT
				;&
			customize)
				;;
			none)
		esac

		check_storage_config

		prompt "Is the storage configuration ok?" STORAGE_OK Y
	done
}

