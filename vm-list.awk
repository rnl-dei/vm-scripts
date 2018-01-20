#!/usr/bin/awk -f

function sep() {
	printf("----------------------------------------------------------------------------------------------------------------------\n")
}

function vmwarn(name, msg) {
	print(RED" --- Possible misconfiguration found on VM "CYAN name RED" ---"NORMAL)
	print("  "msg)
	print("")
}

BEGIN {
	GREEN="\033[0;32m"
	RED="\033[0;31m"
	CYAN="\033[0;36m"
	GRAY="\033[0;90m"
	NORMAL="\033[0m"

	print("Hypervisor info:")

	"nproc" | getline
	TOTAL_CPUS = $1

	print("  "TOTAL_CPUS " CPUs")

	while (getline < "/proc/meminfo") {
		if ($1 == "MemTotal:")
			TOTAL_MEM = int($2 / 1024)
	}
	print("  "TOTAL_MEM " MiB RAM")

	while ("virsh list --name --all" | getline) {
		name = $1

		if(name) {
			while ("virsh dominfo '"name"'" | getline) {

				if ($1 == "State:")
					state[name] = $2$3

				else if ($1 == "CPU(s):")
					cpu[name] = $2

				else if ($1" "$2 == "Used memory:")
					mem[name] = $3/1024

				else if ($1 == "Autostart:")
					autostart[name] = $2
			}

			while ("virsh dumpxml '"name"'" | getline) {
				if (/description/) {
					sub(" *<description>", "")
					sub("</description>", "")
					desc[name] = $0
					break
				}
			}

			while ("virsh domblklist --details '"name"'" | getline) {
				if($2 == "disk") {
					type = $1
					disk = $4
					size = 0

					while ("virsh domblkinfo '"name"' '"disk"' 2>/dev/null" | getline) {
						if($1 == "Capacity:") {
							size = $2

							if (disk in disk_in_use_by) {
								vmwarn(name, "Disk '"disk"' already in use by the VM '"disk_in_use_by[disk]"'")
								continue
							}
							disk_in_use_by[disk] = name

							used_disk[name] += size / 1024 / 1024 / 1000
						}
					}

					if (size == 0) {
						vmwarn(name, "Disk '"disk"' not found")
						continue
					}

					switch(type) {
						case "file":
							cmd = "df --output=target '"disk"'"
							while (cmd | getline);
							close(cmd)
							mountpoint = $1

							switch (mountpoint) {

								case "/dev":
									vmwarn(name, "Disk '"disk"' is configured as a file instead of block device")
									break

								case "":
									vmwarn(name, "Could not find mountpoint of disk '"disk"'")
									break

								default:
									used_disk_path[mountpoint] += size
							}
							break

						case "block":
							cmd = "lvdisplay '"disk"'"
							while (cmd | getline) {
								if (/VG Name/)
									volume = $NF
							}
							close(cmd)
							used_lvm[volume] += size
							break
					}
				}
			}
		}
	}

	printf(" %-20s %-15s %-13s %2s %24s %21s   %s\n", "Name", "State", "Autostart", "#CPU", "Memory", "Disk", "Description")
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
		else if (state[name] == "running")
			color2 = RED
		else
			color2 = GRAY

		if (desc[name] == "")
			desc[name] = RED "EMPTY" NORMAL
		else if (desc[name] == "who knowns...") # The typo is for real :D
			desc[name] = RED desc[name] NORMAL

		printf(" %-20s %s%-15s%s %s%-15s%s %2d %20d MiB %18d GB   %s\n", \
		name, color1, state[name], NORMAL, color2, autostart[name], NORMAL, cpu[name], mem[name], used_disk[name], GRAY desc[name] NORMAL)

	}

	sep()
	printf("Total online:     %33d / %d %12d / %d MiB %18d GB\n", cpu_running, TOTAL_CPUS, mem_running, TOTAL_MEM, disk_running);
	printf("Total configured: %33d / %d %12d / %d MiB %18d GB\n", cpu_all, TOTAL_CPUS, mem_all, TOTAL_MEM, disk_all);

	print("\nStorage stats")

	for (mountpoint in used_disk_path) {
		sep()
		system("df -h "mountpoint)
	}

	for (vg in used_lvm) {
		sep()
		system("vgdisplay --short "vg)
	}
}