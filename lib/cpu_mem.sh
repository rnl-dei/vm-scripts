
function ask_cpu() {
	prompt "Number of CPUs?" NUM_CPU $DEFAULT_NUM_CPU
}

function ask_memory() {
	prompt "Amount of RAM to use? (MB = 1000 KB, MiB = 1024 KiB)" RAM_SIZE $DEFAULT_RAM_SIZE

	# Strip trailing b/B
	RAM_BYTES=$RAM_SIZE
	RAM_BYTES=${RAM_SIZE%b}
	RAM_BYTES=${RAM_SIZE%B}
	RAM_BYTES=$(numfmt --from=auto $RAM_BYTES)

	if (( RAM_BYTES < 1024 * 1024 * 500)); then
		DEFAULT_SWAP_SIZE="512MiB"

	elif (( RAM_BYTES < 1024 * 1024 * 1000)); then
		DEFAULT_SWAP_SIZE="256MiB"
	else
		DEFAULT_SWAP_SIZE="0MiB"
	fi

	prompt "Amount of SWAP to use?" SWAP_SIZE $DEFAULT_SWAP_SIZE
}
