# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit font

DESCRIPTION="Mikachan Japanese TrueType Collection fonts"
HOMEPAGE="http://mikachan-font.com/"
SRC_URI="mirror://gentoo/${P}.tar.bz2
	https://dev.gentoo.org/~flameeyes/dist/${P}.tar.bz2"

LICENSE="free-noncomm"
SLOT="0"
KEYWORDS="~alpha amd64 arm ~hppa ~loong ppc ppc64 ~riscv ~s390 sparc x86"
IUSE=""
# Only installs fonts
RESTRICT="strip binchecks"

FONT_SUFFIX="otf"
FONT_S="${WORKDIR}/${P}"

FONT_CONF=( "${FILESDIR}/60-mikachan_o.conf" )
