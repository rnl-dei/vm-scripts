# Copyright 2016 RNL

EAPI="5"

inherit git-2

DESCRIPTION="Scripts to help manage libvirt VMs"
HOMEPAGE="http://atenas.rnl.tecnico.ulisboa.pt/servidores/vm-scripts"
SRC_URI=""
EGIT_REPO_URI="git://source.rnl.ist.utl.pt/${PN}.git"
EGIT_STORE_DIR="${T}/egit-src"

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

RDEPEND="${DEPEND}"

src_install() {

	newbin vm-create.sh vm-create
	newbin vm-stage4.sh vm-stage4
	newbin vm-list.awk vm-list
	newbin vm-ksm.sh vm-ksm

	exeinto /usr/libexec/vm-scripts/lib
	doexe lib/*.sh

	exeinto /usr/libexec/vm-scripts/templates
	doexe templates/*.sh
}