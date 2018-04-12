# Copyright 2018 RNL

EAPI="6"

inherit git-r3

DESCRIPTION="Scripts to help manage libvirt VMs"
HOMEPAGE="https://ark.rnl.tecnico.ulisboa.pt/Servidores/vm-scripts"
SRC_URI=""
EGIT_REPO_URI="https://source.rnl.tecnico.ulisboa.pt/Servidores/${PN}.git"
EGIT3_STORE_DIR="${T}/egit-src"

if [[ ${PV} == *9999* ]]; then
	EGIT_COMMIT="master"
	KEYWORDS="~amd64"
else
	EGIT_COMMIT="${PV}"
	KEYWORDS="amd64"
fi

LICENSE="BSD-1"
SLOT="0"
IUSE=""

DEPEND=""

RDEPEND="${DEPEND}
	>=app-shells/bash-4
	sys-apps/gawk"

src_install() {

	newbin vm-create.sh vm-create
	newbin vm-stage4.sh vm-stage4
	newbin vm-list.awk vm-list
	newbin vm-ksm.sh vm-ksm
	newbin vm-sysrq.sh vm-sysrq

	exeinto /usr/libexec/${PN}/lib
	doexe lib/*.sh

	exeinto /usr/libexec/${PN}/templates
	doexe templates/*.sh

	insinto /usr/share/${PN}/templates
	doins templates/neo.xml
}
