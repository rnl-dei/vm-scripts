#!/bin/sh

read unshared < /sys/kernel/mm/ksm/pages_unshared
read sharing < /sys/kernel/mm/ksm/pages_sharing
read shared < /sys/kernel/mm/ksm/pages_shared
pagesize=$(getconf PAGESIZE)

deduplicated_ram=$(( sharing * pagesize / 1024 / 1024 ))
shared_ram=$(( shared * pagesize / 1024 / 1024 ))
unshared_ram=$(( unshared * pagesize / 1024 / 1024 ))

echo -e "Pages unshared:\t\t$unshared"
echo -e "Pages sharing:\t\t$sharing (deduplicated)"
echo -e "Pages shared:\t\t$shared"

echo -e "Pages sharing RAM:\t${deduplicated_ram}Mb (deduplicated)"
echo -e "Pages shared RAM:\t${shared_ram}Mb"
echo -e "Pages unshared RAM:\t${unshared_ram}Mb"

echo -e "Saved RAM:\t\t$((deduplicated_ram - shared_ram))Mb"
