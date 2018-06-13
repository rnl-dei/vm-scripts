# vm-scripts

Collection of scripts to manage Virtual Machines using [libvirt](https://libvirt.org/).

## vm-create.sh

Interactive script to create new ready to use VMs with support for:
  * Questions to choose options like CPU number, memory size, etc.
  * Automatic network configuration based on the DNS name match
  * Creation of disks in files and LVM logical volumes
  * OS base image installation from a tarball
  * Scripted base image customization for each OS

## vm-stage4.sh

Create a tar.bz2 with the base image to create new VMs, either from a local directory or a remote host.

## vm-list.awk

Show a resumed list of the VMs configured, with state, autostart, CPUs, memory and disk space used.

## vm-ksm.sh

Show the current usage of the kernel same-page merging.

## KSM init script

[Kernel Samepage Merging (KSM)](https://www.kernel.org/doc/Documentation/vm/ksm.txt) is a Kernel-powered memory-saving de-duplication
daemon that periodically scans the whole memory, looking for pages that can be
merged together in order to save memory.

This init script is used to enable KSM on boot time and see how much memory it's
saving in a human-friendly way.

### Dependencies

* [OpenRC](https://github.com/OpenRC/openrc) (duh)
* [CONFIG_KSM](https://www.kernel.org/doc/Documentation/vm/ksm.txt)=y
* [CONFIG_SYSFS](https://www.kernel.org/doc/Documentation/filesystems/sysfs.txt)=y
* [numfmt (coreutils)](https://www.gnu.org/software/coreutils/manual/html_node/numfmt-invocation.html)
* getconf (glibc)
