function virsh_name_exist() {
	virsh dominfo $1 >/dev/null 2>&1
}

function virsh_cmd() {
	run_silent virsh $@ --config
}

function virsh_define_vm() {
	local name=$1 root_disk_type=$2 root_disk_location=$3

	echo "Configuring VM in libvirt..."

	### Clone the VM config ###

	local xml_file=$(mktemp)

	#virsh dumpxml $TEMPLATE_VM >  $xml_file
	cp $XML_TEMPLATE $xml_file

	sed -i "s#^  <name>.*</name>#  <name>$name</name>#" $xml_file
	sed -i "/^  <uuid>/d" $xml_file

	run_silent virsh define $xml_file

	rm -f $xml_file

	### Change the necessary parts of the VM config ###

	virsh_cmd desc $name "who knowns..."

	virsh_cmd setmaxmem $name $RAM_SIZE
	virsh_cmd setmem $name $RAM_SIZE

	virsh_cmd setvcpus $name --maximum $MAX_NUM_CPU
	virsh_cmd setvcpus $name $NUM_CPU

	virsh_cmd detach-interface $name bridge
	virsh_cmd attach-interface $name bridge $INTERFACE --target tap-$name --model virtio

	virsh_cmd detach-disk $name vda

	virsh_cmd desc $name ""

	local tmp_file=$(mktemp)

	case $ROOT_DISK_TYPE in
		file)

cat << EOF > $tmp_file
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native'/>
      <source file='$root_disk_location'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </disk>
EOF

			virsh_cmd attach-device $name $tmp_file

			rm -f $tmp_file
			;;
		lvm)
			warning TODO
			exit
			;;
		none)
			;;
	esac
}

function virsh_get_mac_address() {
	local name=$1
	echo $(virsh domiflist $name | awk '/bridge/{print$NF}')
}
