# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{10..12} pypy3 )

inherit distutils-r1

DESCRIPTION="A Python module for making simple text/console-mode user interfaces"
HOMEPAGE="https://pythondialog.sourceforge.io/"
SRC_URI="https://downloads.sourceforge.net/project/${PN}/${PN}/${PV}/python3-${P}.tar.bz2"

LICENSE="LGPL-2"
SLOT="0"
KEYWORDS="~alpha amd64 ~arm ppc ~riscv sparc x86"

RDEPEND="dev-util/dialog"

distutils_enable_sphinx doc

python_prepare_all() {
	distutils-r1_python_prepare_all
	sed -e "/^    'sphinx.ext.intersphinx',/d" -i doc/conf.py || die
}

python_install_all() {
	dodoc -r examples
	docompress -x /usr/share/doc/${PF}/examples
	distutils-r1_python_install_all
}
