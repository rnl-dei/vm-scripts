#!/bin/bash

EXCLUDE="
./swapfile
./root/.vim_tmp/*
./root/.ansible
./root/.ssh/known_hosts
./root/.rnd
./root/.bash_history
./etc/ssh/ssh_host_*
./etc/config-archive/*
./var/lib/cdist
./var/log/*
./dev/*
./tmp/*
"

function tar_cmd {
	echo "tar cjf - --totals=USR1 -C $1 . --one-file-system --exclude-backups --exclude-from=-"
}

function progress_signal {
	echo "sleep 1; while pgrep tar; do pkill -USR1 tar; sleep 5; done"
}

FILE=$1
DIRECTORY=${2%/}
HOST=$3

if [ ! -d $(dirname "$FILE") ]; then
	echo "$FILE path not found"
	exit
fi

if [[ "$DIRECTORY" != "" && "$DIRECTORY" != "ssh" ]]; then
	
	if [ ! -d "$DIRECTORY" ]; then
		echo "$DIRECTORY is not a valid directory"

	elif [ ! -x "${DIRECTORY}/sbin/init" ]; then
		echo "${DIRECTORY}/sbin/init not found. Are you sure this is a valid root filesystem? Maybe you forget to mount it?"

	else
		echo "Building stage4 from local directory $DIRECTORY"
		eval $(progress_signal) >/dev/null &
		echo "$EXCLUDE" | $(tar_cmd $DIRECTORY) > "$FILE"
		echo "Done"
	fi

elif [[ $DIRECTORY == "ssh" && $HOST != "" ]]; then

	echo "Building stage4 from remote host $HOST"
	ssh $HOST "$(progress_signal $HOST)" >/dev/null &
	echo "$EXCLUDE" | ssh $HOST "$(tar_cmd /)" > "$FILE"
	echo "Done"

else
	echo -e "To build from a directory on the current host: \t\t $0 <file> <directory>"
	echo -e "To build from the root of a running remote system: \t $0 <file> ssh <host>"
fi


