# Gentoo specific template

STAGE4_FILE=/var/db/repos/rnl/stage4/stage4-gentoo.tar.bz2

HOSTNAME_FILE="$NEWVM_MOUNTPOINT/etc/conf.d/hostname"
NETWORKING_FILE="$NEWVM_MOUNTPOINT/etc/conf.d/net"

# crontab files which need to be randomized
CRONTAB_FILES="$NEWVM_MOUNTPOINT/etc/crontab
	$NEWVM_MOUNTPOINT/etc/cron.d/dailyjobs
	$NEWVM_MOUNTPOINT/etc/cron.d/0hourly
"

SSMTP_FILE="$NEWVM_MOUNTPOINT/etc/ssmtp/ssmtp.conf"
SNMPD_FILE="$NEWVM_MOUNTPOINT/etc/snmp/snmpd.conf"

# randomize crontab files so machines don't run them at the same time
# only changes the "minutes" field of known cronjobs
function randomize_cron_file {
	local CRONTAB_FILE="$1"
	TMP_FILE=$(mktemp) || return 1

	cp $CRONTAB_FILE $TMP_FILE || return 1

	awk '
	BEGIN {
		srand(systime())
	}
	{
		if(/^[ \t]*([0-9*]+[ \t]+){5}.*(run-parts|lastrun).*\/cron\.)/) {
			# replace the first field (minute)
			$1 = int(rand() * 60)
		}
		print
	}
	' $TMP_FILE > $CRONTAB_FILE || return 1

	rm -f $TMP_FILE
	return 0
}

function customize_disk {

	if [ -z $NEWVM_MOUNTPOINT ]; then
		warning "Ups, NEWVM_MOUNTPOINT not defined in customize_disk, bye"
		exit
	fi

	source ${TEMPLATES_LOCATION}/generic.sh

	echo "Customizing the Gentoo disk image..."

	# Set the hostname

	echo "hostname=\"$NAME\"" > $HOSTNAME_FILE

	# Network configuration

	echo -e "dns_servers=\"$DNS_SERVERS\"" > $NETWORKING_FILE
	echo -e "dns_search=\"rnl.tecnico.ulisboa.pt\"" >> $NETWORKING_FILE

	if [[ $IP6 != "" ]]; then
		echo -e "config_lan0=\"$IP/$NETMASK\n$IP6/$NETMASK6\"" >> $NETWORKING_FILE
		echo -e "routes_lan0=\"default via $GATEWAY\ndefault via $GATEWAY6\"" >> $NETWORKING_FILE
	else
		echo -e "config_lan0=\"$IP/$NETMASK\"" >> $NETWORKING_FILE
		echo -e "routes_lan0=\"default via $GATEWAY\"" >> $NETWORKING_FILE
	fi

	# Randomize cronjob times
	for tab in $CRONTAB_FILES; do
		randomize_cron_file $tab || warning "Failed to randomize crontab $tab"
	done

	# Email configuration

	sed -i -e "s/^rewriteDomain.*/rewriteDomain=$NAME.rnl.tecnico.ulisboa.pt/" \
	       -e "s/^hostname.*/hostname=$NAME.rnl.tecnico.ulisboa.pt/" $SSMTP_FILE

	# snmpd configuration

	sed -i "s/^sysname.*/sysname ${NAME^}/" $SNMPD_FILE
}
