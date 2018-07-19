# Copyright 2018 RNL

EAPI="6"

inherit git-r3 linux-info

DESCRIPTION="Scripts to help manage libvirt VMs"
HOMEPAGE="https://ark.rnl.tecnico.ulisboa.pt/Servidores/vm-scripts"
SRC_URI=""
EGIT_REPO_URI="https://source.rnl.tecnico.ulisboa.pt/Servidores/${PN}.git"
EGIT3_STORE_DIR="${T}/egit-src"

if [[ ${PV} == *9999* ]]; then
	KEYWORDS="~amd64"
else
	EGIT_COMMIT="${PV}"
	KEYWORDS="amd64"
fi

LICENSE="BSD-1"
SLOT="0"
IUSE="doc"

DEPEND=""

RDEPEND="${DEPEND}
	>=app-shells/bash-4
	sys-apps/coreutils
	app-misc/timestamp
	app-emulation/libvirt
	sys-apps/gawk"

src_install() {

	newbin vm-create.sh vm-create
	newbin vm-stage4.sh vm-stage4
	newbin vm-list.awk vm-list
	newbin vm-ksm.sh vm-ksm
	newbin vm-sysrq.sh vm-sysrq
	newbin vm-baseline.sh vm-baseline

	exeinto /usr/libexec/${PN}/lib
	doexe lib/*.sh

	exeinto /usr/libexec/${PN}/templates
	doexe templates/*.sh

	insinto /usr/share/${PN}/templates
	doins templates/neo.xml

	if use doc; then
		local d
		for d in README.*; do
			dodoc $d
		done
	fi

	newinitd ksm.init ksm
}

pkg_pretend() {
	local CONFIG_CHECK="~KSM ~SYSFS"
	local WARNING_KSM="CONFIG_KSM is required for KSM support."
	local WARNING_SYSFS="CONFIG_SYSFS is required for enabling KSM."
	[[ ${MERGE_TYPE} != buildonly ]] && check_extra_config
}
