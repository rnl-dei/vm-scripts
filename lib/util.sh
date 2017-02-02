CYAN="\e[0;36m"
RED="\e[1;31m"
YELLOW="\e[0;33m"
GRAY="\e[0;90m"
NORMAL="\e[0m"

function prompt() {
	local message=$1 var=$2 default="$3" option=""

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
	[[ $tmp == "" ]] && tmp="$default"
	eval $var=\"$tmp\"
}

function warning() {
	echo -e $RED"$1"$NORMAL
}

function info() {
	echo -e $CYAN"  $1"$NORMAL
}

function set_name() {
	unset NAME
	while [[ $NAME == "" ]]; do
		prompt "Name (it is best to match exactly the DNS domain)?" NEWNAME
		if virsh_name_exist $NEWNAME; then
			 warning "A VM with that name already exist!"
			 echo "Hit Ctrl+C and run 'virsh undefine $NEWNAME' if you really want to delete the existing VM '$NEWNAME'."
		else
			NAME=$NEWNAME
		fi
	done
}

function quote_output() {
	while read line; do
		echo -e " $GRAY$line$NORMAL"
	done
}

function run() {
	if [ ! $DRYRUN ]; then
		$@
	fi
}

function run_silent() {
	if [ $DEBUG ]; then
		echo "Running \"$@\""
		run $@ | quote_output
	else
		run $@ >/dev/null
	fi
}
