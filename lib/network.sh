
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

function ip_from_dns() {
	IP=$(host -t A $1 | awk '/has address/{print $NF}')
	IP6=$(host -t AAAA $1 | awk '/has IPv6 address/{print $NF}')
}

function dns_from_ip() {
	REVERSE_DNS=$(host $1 | awk '/domain name pointer/{print $NF}')
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

function ask_network_settings {
	NETWORK_OK="n"
	while [[ $NETWORK_OK == "n" ]]; do

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

		info "Matching DNS name found: $NAME"
		info "IPv4 address: $IP/$NETMASK"
		info "IPv4 gateway: $GATEWAY"
		if [[ $IP6 != "" ]]; then
			info "IPv6 address: $IP6/$NETMASK6"
			info "IPv6 gateway: $GATEWAY6"
		else
			info "No IPv6 address found for $NAME"
		fi
		info "Network interface: $INTERFACE"
		prompt "Is the network configuration ok?" NETWORK_OK Y
	done
}
