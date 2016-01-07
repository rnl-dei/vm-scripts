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
TEMPLATE_VM="neo"
TEMPLATE_MOUNTPOINT="/mnt/template"
NEWVM_MOUNTPOINT="/mnt/newvm"

HOSTNAME_FILE="$NEWVM_MOUNTPOINT/etc/conf.d/hostname"
UDEV_INTERFACE_FILE="$NEWVM_MOUNTPOINT/etc/udev/rules.d/70-custom-net-names.rules"
NETWORKING_FILE="$NEWVM_MOUNTPOINT/etc/conf.d/net"
CRONTAB_FILE="$NEWVM_MOUNTPOINT/etc/crontab"
SSMTP_FILE="$NEWVM_MOUNTPOINT/etc/ssmtp/ssmtp.conf"
SNMPD_FILE="$NEWVM_MOUNTPOINT/etc/snmp/snmpd.conf"

CYAN="\e[0;36m"
RED="\e[1;31m"
YELLOW="\e[0;33m"
GRAY="\e[0;90m"
NORMAL="\e[0m"

DNS_SERVERS="193.136.164.1 193.136.164.2"

INTERFACES=(pub priv dmz labs gia portateis)

declare -A NETWORK_INTERFACE=(
	[pub]=pub
	[priv]=priv
	[dmz]=dmz
	[labs]=labs
	[labs2]=labs
	[cluster]=labs
	[gia-priv]=gia
	[portateis]=portateis
)

declare -A NETMASKS=(
	[pub]=26
	[priv]=26
	[dmz]=26
	[labs]=25
	[labs2]=26
	[cluster]=24
	[gia-priv]=24
	[portateis]=23
)

declare -A IPRANGES_THIRD=(
	["193.136.164"]="pub priv dmz"
	["193.136.154"]="labs labs2"
	["192.168.77"]="cluster"
	["10.16.80"]="portateis"
	["10.16.81"]="portateis"
	["10.16.86"]="gia-priv"
)

declare -A IPRANGES_FOURTH=(
	[pub]="1 62"
	[priv]="64 126"
	[dmz]="129 190"
	[labs]="1 126"
	[labs2]="129 190"
	[cluster]="1 254"
	[gia-priv]="1 254"
	[portateis]="1 254"
)

### Functions ###

function prompt() {
	local message=$1 var=$2 default=$3 option=""

	if [[ $default = [yY] ]]; then
		option="[Y/n] "
	elif [[ $default = [nN] ]]; then
		option="[y/N] "
	elif [[ $default != "" ]]; then
		option="[$default] "
	fi

	echo -e -n $YELLOW"$message $option"$NORMAL

	local tmp
	read tmp
	[[ $tmp == "" ]] && tmp=$default
	eval $var=$tmp
}

function warning() {
	echo -e $RED"$1"$NORMAL
}

function name_exist() {
	virsh dominfo $1 >/dev/null 2>&1
}

function ip_from_dns() {
	IP=$(host -t A $1 | awk '/has address/{print $NF}')
	IP6=$(host -t AAAA $1 | awk '/has IPv6 address/{print $NF}')
}

function dns_from_ip() {
	REVERSE_DNS=$(host $1 | awk '/domain name pointer/{print $NF}')
}

function set_name() {
	while [[ $NAME == "" ]]; do
		prompt "Name (it is best to match exactly the DNS domain)?" NEWNAME

		name_exist $NEWNAME && warning "A VM with that name already exist!" || NAME=$NEWNAME
	done
}

function network_from_ip() {
	NETWORK_ADDR=${1%.*}
	HOST_ADDR=${1#$NETWORK_ADDR.}

	for network in ${IPRANGES_THIRD[$NETWORK_ADDR]}; do
		RANGE=( ${IPRANGES_FOURTH[$network]} )
		if [ $HOST_ADDR -ge ${RANGE[0]} -a $HOST_ADDR -le ${RANGE[1]} ]; then
			NETWORK=$network
			break
		fi
	done
}

function set_ip() {
	echo "How do you want to choose the IP?"
	echo "  1 - Define the IP address in the DNS server."
	echo "  2 - Change the VM name to match an existing DNS name."
	echo "  3 - Type the IP address to use."
	echo "  0 - Flip the table."

	prompt "?" OPTION
	case $OPTION in
		1)
			prompt "Press Enter when you have already defined the DNS A record for \"$NAME\" "
			;;
		2)
			NAME=""
			set_name
			ip_from_dns $NAME
			;;
		3)
			prompt "Type the IP address: " IP
			;;
		0)
			echo "Bye bye..."
			exit
			;;
	esac
}

function set_network() {
	echo "How to you want to get the network details?"
	echo "  1 - Change the IP address."
	echo "  2 - Configure the network details."
	echo "  0 - Flip the table."

	prompt "?" OPTION
	case $OPTION in
		1)
			IP=""
			set_ip
			network_from_ip $IP
			;;
		2)
			echo "Type the missing parameters for IP \"$IP\""
			prompt "Netmask (28 for example):" NETMASK
			prompt "Gateway : " GATEWAY
			echo "Interface to assign to the VM?"
			while [[ $INTERFACE == "" ]]; do
				for i in {0..5}; do
					echo "    $i - ${INTERFACES[$i]}"
				done
				prompt "?" OPTION
				INTERFACE=${INTERFACES[$OPTION]}
			done
			NETWORK="custom"
			;;
		0)
			echo "Bye bye..."
			exit
			;;
	esac
}

function auto_configure_network() {
	NETMASK=${NETMASKS[$1]}
	GATEWAY=$(host -t A gt$1 | awk '/has address/{print $NF}')

	NETMASK6=64
	GATEWAY6=$(host -t AAAA gt$1 | awk '/has IPv6 address/{print $NF}')

	INTERFACE=${NETWORK_INTERFACE[$1]}
}

function virsh_cmd() {
	virsh $@ --config >/dev/null
}

function quote_output() {
	while read line; do
		echo -e " $GRAY$line$NORMAL"
	done
}

### MAIN ###

echo "Answer the details below so that I can configure the VM and change the disk image to match the details provided."
echo

### Network Stuff ###

NETWORK_OK="n"
while [[ $NETWORK_OK == "n" ]]; do
	unset NAME
	set_name

	ip_from_dns $NAME

	while [[ $IP == "" ]]; do
		warning "The name you gave doesn't have an IP address defined in the DNS server!"
		set_ip
	done

	network_from_ip $IP

	while [[ $NETWORK == "" ]]; do
		warning "The IP you gave doesn't seem to match a network available in this server!"
		set_network
	done

	dns_from_ip $IP

	while [[ $NETWORK != "custom" && $REVERSE_DNS == "" ]]; do
		warning "You did not setup the reverse record for $NAME.rnl.tecnico.ulisboa.pt in the DNS server!"
		prompt "Did you fix it already?" REVERSE_DNS
	done

	if [[ $NETWORK != "custom" ]]; then
		auto_configure_network $NETWORK
	fi

	echo "Name: $NAME"
	echo "IPv4 address: $IP/$NETMASK"
	echo "IPv4 gateway: $GATEWAY"
	if [[ $IP6 != "" ]]; then
		echo "IPv6 address: $IP6/$NETMASK6"
		echo "IPv6 gateway: $GATEWAY6"
	else
		echo "No IPv6 address found for $NAME"
	fi
	echo "Network interface: $INTERFACE"
	prompt "Is the network configuration ok?" NETWORK_OK Y
done

### Ask other stuff ###

prompt "Amount of RAM to use?" RAM_SIZE $DEFAULT_RAM_SIZE
prompt "Number of CPUs?" NUM_CPU $DEFAULT_NUM_CPU
prompt "Size of the root disk image in GB (the base system requires at least 1Gb)?" DISK_SIZE $DEFAULT_DISK_SIZE


DISK_NAME=$NAME
DISK_FILE=$DISK_LOCATION/$DISK_NAME.img
CREATE_DISK=true

if [ -a "$DISK_FILE" ]; then
	warning "A disk file with the name $DISK_NAME.img already exists!"
	echo "What do you want to do?"
	echo "  1 - Choose a different name."
	echo "  2 - Use the existing disk"
	echo "  0 - Flip the table."

	prompt "?" OPTION
	case $OPTION in
		1)
			while [ -a "$DISK_FILE" ]; do
				prompt "Type the new disk name: " DISK_NAME
				DISK_FILE=$DISK_LOCATION/$DISK_NAME.img
			done
			;;
		2)
			CREATE_DISK=false
			;;
		0)
			echo "Bye bye..."
			exit
			;;
		*)
			CREATE_DISK=false
			;;
	esac
fi

### Clone the VM config ###

XML_FILE=$(mktemp)

virsh dumpxml $TEMPLATE_VM >  $XML_FILE

sed -i "s#^  <name>.*</name>#  <name>$NAME</name>#" $XML_FILE
sed -i "/^  <uuid>/d" $XML_FILE

virsh define $XML_FILE >/dev/null

rm -f $XML_FILE

### Change the necessary parts of the VM config ###

virsh_cmd desc $NAME "who knowns..."

virsh_cmd setmaxmem $NAME $RAM_SIZE
virsh_cmd setmem $NAME $RAM_SIZE

virsh_cmd setvcpus $NAME --maximum $MAX_NUM_CPU
virsh_cmd setvcpus $NAME $NUM_CPU

virsh_cmd detach-interface $NAME bridge
virsh_cmd attach-interface $NAME bridge $INTERFACE --target tap-$NAME --model virtio

virsh_cmd detach-disk $NAME vda

virsh_cmd desc $NAME ""

TMP_FILE=$(mktemp)

cat << EOF > $TMP_FILE
    <disk type='file' device='disk'>
      <driver name='qemu' type='raw' cache='none' io='native'/>
      <source file='$DISK_FILE'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </disk>
EOF

virsh_cmd attach-device $NAME $TMP_FILE

rm -f $TMP_FILE

MAC_ADDRESS=$(virsh domiflist $NAME | awk '/bridge/{print$NF}')

### Create the new root disk image ###

if $CREATE_DISK; then

	# Criar o disco

	echo "Creating the disk image file, this may take a while..."
	dd if=/dev/zero of=$DISK_FILE bs=1M count=$((DISK_SIZE*1000)) 2>&1 | quote_output

	# Formatar o disco

	echo "Formating disk to ext4..."
	#mkfs.ext4 -F -E lazy_itable_init=0 -E nodiscard -L "${NAME}_root" $DISK_FILE 2>&1 | quote_output
	mkfs.ext4 -F -E nodiscard -L "${NAME}_root" $DISK_FILE 2>&1 | quote_output

	# Montar as imagens em device loops

	mkdir -p $NEWVM_MOUNTPOINT
	mount -o loop $DISK_FILE $NEWVM_MOUNTPOINT

	mkdir -p $TEMPLATE_MOUNTPOINT
	mount -o loop $DISK_LOCATION/$TEMPLATE_VM.img $TEMPLATE_MOUNTPOINT

	# Copiar o disco de template para o novo disco

	echo 'Copying the template to the disk...'
	rsync --archive --numeric-ids $TEMPLATE_MOUNTPOINT/ $NEWVM_MOUNTPOINT \
	--exclude='/var/log/' --exclude='/etc/ssh/ssh_host*'

	echo "Customizing the disk image..."

	# Definir o hostname

	echo "hostname=\"$NAME\"" > $HOSTNAME_FILE
	
	# Actualizar o MAC address na regra do udev

	echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"lan0\"" > $UDEV_INTERFACE_FILE

	# Configurar a rede

	echo -e "dns_servers=\"$DNS_SERVERS\"" > $NETWORKING_FILE
	echo -e "dns_search=\"rnl.tecnico.ulisboa.pt\"" >> $NETWORKING_FILE

	if [[ $IP6 != "" ]]; then
		echo -e "config_lan0=\"$IP/$NETMASK\n$IP6/$NETMASK6\"" >> $NETWORKING_FILE
		echo -e "routes_lan0=\"default via $GATEWAY\ndefault via $GATEWAY6\"" >> $NETWORKING_FILE
	else
		echo -e "config_lan0=\"$IP/$NETMASK\"" >> $NETWORKING_FILE
		echo -e "routes_lan0=\"default via $GATEWAY\"" >> $NETWORKING_FILE
	fi

	# Randomizar as horas dos cronjobs
	
	TMP_FILE=$(mktemp)
	
	cp $CRONTAB_FILE $TMP_FILE

	cat $TMP_FILE | awk '
	BEGIN {
		srand(systime())
		hourly = int(rand() * 60)
		other = int(rand() * 60)
	}
	{
		if(/lastrun\/cron.hourly$/)
			printf("%2d %s  %s %s %s\troot\trm -f %s\n", hourly, $2, $3, $4, $5, $NF)
		else if (/lastrun\/cron..*$/)
			printf("%2d %s  %s %s %s\troot\trm -f %s\n", other, $2, $3, $4, $5, $NF)
		else
			print
	}
	' > $CRONTAB_FILE

	rm -f $TMP_FILE

	# Configurar o email

	sed -i -e "s/^rewriteDomain.*/rewriteDomain=$NAME.rnl.tecnico.ulisboa.pt/" \
	       -e "s/^hostname.*/hostname=$NAME.rnl.tecnico.ulisboa.pt/" $SSMTP_FILE

	# Configurar o snmpd

	sed -i "s/^sysname.*/sysname ${NAME^}/" $SNMPD_FILE

	# Copiar as chaves de SSH do zion

	cp /root/.ssh/authorized_keys $NEWVM_MOUNTPOINT/root/.ssh/

	# Desmontar tudo

	umount $TEMPLATE_MOUNTPOINT
	rmdir $TEMPLATE_MOUNTPOINT

	umount $NEWVM_MOUNTPOINT
	rmdir $NEWVM_MOUNTPOINT

fi

echo "Profit!"
echo "Run \"virsh start $NAME\" to start the VM."
