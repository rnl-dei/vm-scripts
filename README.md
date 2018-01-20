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
