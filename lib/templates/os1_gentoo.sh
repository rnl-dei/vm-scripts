# Gentoo specific template

STAGE4_FILE=/root/vm-scripts/neo-stage4.tar.bz2

CLEAN_VM=neo

HOSTNAME_FILE="$NEWVM_MOUNTPOINT/etc/conf.d/hostname"
NETWORKING_FILE="$NEWVM_MOUNTPOINT/etc/conf.d/net"
CRONTAB_FILE="$NEWVM_MOUNTPOINT/etc/crontab"
SSMTP_FILE="$NEWVM_MOUNTPOINT/etc/ssmtp/ssmtp.conf"
SNMPD_FILE="$NEWVM_MOUNTPOINT/etc/snmp/snmpd.conf"

function customize_disk {

	if [ -z $NEWVM_MOUNTPOINT ]; then
		warning "Ups, NEWVM_MOUNTPOINT not defined in customize_disk, bye"
		exit
	fi

	source ${LIB_LOCATION}/templates/generic.sh

	echo "Customizing the Gentoo disk image..."

	# Definir o hostname

	echo "hostname=\"$NAME\"" > $HOSTNAME_FILE
	
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
}
