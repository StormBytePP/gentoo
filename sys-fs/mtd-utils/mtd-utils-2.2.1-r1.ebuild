# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

DESCRIPTION="MTD userspace tools (NFTL, JFFS2, NAND, FTL, UBI)"
HOMEPAGE="https://git.infradead.org/?p=mtd-utils.git;a=summary"
SRC_URI="https://infraroot.at/pub/mtd/${P}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~arm ~arm64 ~loong ~mips ppc ppc64 ~riscv ~x86 ~amd64-linux ~x86-linux"
IUSE="+lzo +ssl test xattr +zstd ubifs"
REQUIRED_USE="ubifs? ( lzo ssl xattr zstd )"
RESTRICT="!test? ( test )"

DEPEND="
	sys-apps/util-linux:=
	sys-libs/zlib:=
	lzo? ( dev-libs/lzo:= )
	ssl? ( dev-libs/openssl:0= )
	xattr? ( sys-apps/acl )
	zstd? ( app-arch/zstd:= )
"
RDEPEND="${DEPEND}"
BDEPEND="test? ( dev-util/cmocka )"

DOCS=( jffsX-utils/device_table.txt ubifs-utils/mkfs.ubifs/README )

src_prepare() {
	default
	sed -i '/if test.*then/s: == : = :' configure || die
}

src_configure() {
	# --with-tests is for test programs that are installed; was --enable-tests in earlier versions
	local myeconfargs=(
		--with-tests
		--with-zlib
		--enable-ubihealthd
		--with-lsmtd
		--with-jffs
		$(use_enable test unit-tests)
		$(use_with lzo)
		$(use_with xattr)
		$(use_with zstd)
		$(use_with ubifs)
		$(use_with ubifs crypto) # UBIFS-specific crypto support
	)
	econf "${myeconfargs[@]}"
}

src_compile() {
	emake AR="$(tc-getAR)"
}

src_install() {
	default
	doman \
		jffsX-utils/mkfs.jffs2.1 \
		ubi-utils/ubinize.8
}
