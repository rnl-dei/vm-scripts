echo "Customizing generic stuff..."

UDEV_INTERFACE_FILE="$NEWVM_MOUNTPOINT/etc/udev/rules.d/70-custom-net-names.rules"

# Actualizar o MAC address na regra do udev
MAC_ADDRESS=$(virsh_get_mac_address $NAME)
echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$MAC_ADDRESS\", NAME=\"lan0\"" > $UDEV_INTERFACE_FILE

# Copiar as chaves de SSH do zion
cp /root/.ssh/authorized_keys $NEWVM_MOUNTPOINT/root/.ssh/
