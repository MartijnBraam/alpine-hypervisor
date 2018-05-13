pkgname="webui"

depends="python3 py3-flask debootstrap qemu qemu-img lxc bridge lxc-templates blkid"
makedepends="python3-dev"

pkgver=1
pkgrel=0
pkgdesc="Hypervisor webui"
url="http://example.com/"
arch="all"
license="GPL"
source="webui.tar.gz"

builddir="$srcdir/$pkgname"

build() {
	cd "$builddir"
	python3 setup.py build
}

check() {
	cd "$builddir"
	python3 setup.py test
}

package() {
	cd "$builddir"
	install -Dm755 "${builddir}/webui.init" \
        "${pkgdir}/etc/init.d/webui"
	python3 setup.py install --prefix=/usr --root="$pkgdir"
}
