#!/usr/bin/awk -f

function sep() {
	printf("-----------------------------------------------------------------------------------------------------\n")
}

BEGIN {
	TOTAL_MEM = 96740
	TOTAL_CPU = 32
	TOTAL_DISK = 3000

	GREEN="\033[0;32m"
	RED="\033[0;31m"
	GRAY="\033[0;90m"
	NORMAL="\033[0m"

	while ("virsh list --name --all" | getline) {
		name = $1

		if(name) {
			while ("virsh dominfo "name | getline)

				if ($1 == "State:")
					state[name] = $2$3

				else if ($1 == "CPU(s):")
					cpu[name] = $2

				else if ($1" "$2 == "Used memory:")
					mem[name] = $3/1024

				else if ($1 == "Autostart:")
					autostart[name] = $2

			while ("virsh domblklist --details "name | getline)
				if($2 == "disk") {
					disk = $4
					while ("virsh domblkinfo "name" "disk | getline) {
						if($1 == "Capacity:")
							used_disk[name] += $2/1024/1024/1000
					}
				}
		}
	}

	printf(" %-15s %-15s %-13s %2s %24s %21s\n", "Name", "State", "Autostart", "#CPU", "Memory", "Disk")
	sep()
	n = -1
	for(name in state) {

		if (++n == 5) {
			sep()
			n = 0
		}


		if (state[name] == "running") {
			color1 = GREEN
			mem_running += mem[name]
			cpu_running += cpu[name]
			disk_running += used_disk[name]
		}
		else {
			color1 = GRAY
		}
		mem_all += mem[name]
		cpu_all += cpu[name]
		disk_all += used_disk[name]

		if (autostart[name] == "enable")
			color2 = GREEN
		else
			color2 = GRAY

		printf(" %-15s %s%-15s%s %s%-15s%s %2d %20d MiB %18d GB\n", \
		name, color1, state[name], NORMAL, color2, autostart[name], NORMAL, cpu[name], mem[name], used_disk[name])

	}

	sep()
	printf("Total online:     %28d / %d %12d / %d MiB %11d / %d GB\n", cpu_running, TOTAL_CPU, mem_running, TOTAL_MEM, disk_running, TOTAL_DISK);
	printf("Total configured: %28d / %d %12d / %d MiB %11d / %d GB\n", cpu_all, TOTAL_CPU, mem_all, TOTAL_MEM, disk_all, TOTAL_DISK);


}


