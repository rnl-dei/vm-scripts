function ip_from_dns() {
	[[ ! "$1" ]] && error "ip_from_dns() No argument given!" && exit 1
	IP=$(host -t A $1 | awk '/has address/{print $NF}')
	IP6=$(host -t AAAA $1 | awk '/has IPv6 address/{print $NF}')
}

function dns_from_ip() {
	[[ ! "$1" ]] && error "dns_from_ip() No argument given!" && exit 1
	REVERSE_DNS=$(host $1 | awk '/domain name pointer/{print $NF}')
}

function get_bridges() {
	ip link show type bridge | awk -F ": " '/^[[:digit:]]/{print $2}'
}

function network_from_ip() {
	local ip=$1
	local network gateway netmask

	while read key value; do
		key=${key,,} # Lowercase
		key=${key%:} # Remove trailing :
		case ${key} in
			vlan)    network=$value ;;
			gateway) gateway=$value ;;
			subnet)  netmask=${value#*/} ;;

		esac
	# The output from whois must be given this way instead of a normal pipe
	# because the variable assignments above are useless if done in a subshell
	done < <(whois $ip)

	NETWORK=$network
	INTERFACE=$network

	if [[ $ip =~ : ]]; then
		GATEWAY6=$gateway
		NETMASK6=$netmask
	else
		GATEWAY=$gateway
		NETMASK=$netmask
	fi

	[[ ! "$DNS_SERVERS" ]] && DNS_SERVERS="$(whois dns1) $(whois dns2)"
}

function set_ip() {
	echo "How do you want to choose the IP?"
	echo "  1 - Define the IP address in the DNS server."
	echo "  2 - Change the VM name to match an existing DNS name."
	echo "  3 - Use another existing DNS name (not recommented)."
	echo "  4 - Type the IP address to use."
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
			prompt "What is the DNS name?" DNS_NAME $NAME
			ip_from_dns $DNS_NAME
			;;
		4)
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

			local interfaces=( $(get_bridges) )

			while [[ $INTERFACE == "" ]]; do
				for i in $(seq 0 $(( ${#interfaces[@]} - 1)) ); do
					echo "    $i - ${interfaces[$i]}"
				done
				prompt "?" OPTION
				INTERFACE=${interfaces[$OPTION]}
			done
			NETWORK="custom"
			;;
		0)
			echo "Bye bye..."
			exit
			;;
	esac
}

function ask_network_settings {

	[[ ! "$NAME" ]] && error "network.sh: \$NAME not defined" && exit 1

	NETWORK_OK="n"
	while [[ $NETWORK_OK == "n" ]]; do

		ip_from_dns $NAME

		while [[ $IP == "" ]]; do
			warning "The name you gave doesn't have an IP address defined in the DNS server!"
			set_ip
		done

		network_from_ip $IP
		[[ $IP6 != "" ]] && network_from_ip $IP6

		while [[ $NETWORK == "" ]]; do
			warning "The IP you gave doesn't seem to match a network available in this server!"
			set_network
		done

		dns_from_ip $IP

		while [[ $NETWORK != "custom" && $REVERSE_DNS == "" ]]; do
			warning "You did not setup the reverse record for $NAME in the DNS server!"
			prompt "Did you fix it already?" REVERSE_DNS
		done

		info "Matching DNS name found: $REVERSE_DNS"

		info "IPv4 address: $IP/$NETMASK"
		info "IPv4 gateway: $GATEWAY"

		if [[ $IP6 != "" ]]; then
			info "IPv6 address: $IP6/$NETMASK6"
			info "IPv6 gateway: $GATEWAY6"
		else
			info "No IPv6 address found for $NAME"

		fi
		info "DNS servers: $DNS_SERVERS"
		info "Network interface: $INTERFACE"

		prompt "Is the network configuration ok?" NETWORK_OK Y
	done
}
