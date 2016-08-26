echo "Customizing generic stuff..."

UDEV_INTERFACE_FILE="${NEWVM_MOUNTPOINT}/etc/udev/rules.d/70-custom-net-names.rules"

# Actualizar o MAC address na regra do udev
MAC_ADDRESS=$(virsh_get_mac_address $NAME)
echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"lan0\"" > $UDEV_INTERFACE_FILE

# Copiar as chaves de SSH do zion
cp /root/.ssh/authorized_keys ${NEWVM_MOUNTPOINT}/root/.ssh/

# Criar swap file se definido
if [[ ! $SWAP_SIZE =~ ^0 ]]; then

	case $SWAP_SIZE in
		*MiB)
			block_size=1MiB
			count=${SWAP_SIZE%MiB}
			;;
		*GiB)
			block_size=1MiB
			count=${SWAP_SIZE%GiB}
			count=$((count * 1024))
			;;
		*MB)
			block_size=1MB
			count=${SWAP_SIZE%MB}
			;;
		*GB)
			block_size=1MB
			count=${SWAP_SIZE%GB}
			count=$((count * 1000))
			;;
		*)
			warning "Swap size must have one of the following units: MiB, GiB, MB or GB. Going with 256MiB of swap."
			block_size=1MiB
			count=256

	esac

	dd if=/dev/zero of=${NEWVM_MOUNTPOINT}/swapfile bs=${block_size} count=${count}

# Ou comentar no fstab (caso o template tenha swap configurada)
else
	sed -i "s/^\/swapfile/#\/swapfile/" ${NEWVM_MOUNTPOINT}/etc/fstab
fi
