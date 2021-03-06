MIRROR := http://dl-cdn.alpinelinux.org/alpine
ALPINEVER := v3.9
BUILDDIR:= build
ROOT:=$(BUILDDIR)/rootfs
BUILDCHROOT:=$(BUILDDIR)/buildchroot
REPO:=$(BUILDDIR)/repo
APATH:=PATH=/usr/sbin:/usr/bin:/sbin:/bin

PACKAGES:=$(REPO)/x86_64/webui-1-r0.apk $(REPO)/x86_64/util-linux-2.32-r0.apk $(REPO)/x86_64/libscrypt-1.21-r0.apk $(REPO)/x86_64/bcachefs-tools-1-r0.apk $(REPO)/x86_64/linux-hypervisor-4.16.0-r0.apk

build/hypervisor.vdi: build/hypervisor.img
	@echo MKIMG creating hypervisor.vdi
	qemu-img convert -O vdi -f raw $< $@

build/hypervisor.img: chroot
	@echo MKIMG creating hypervisor.img
	dd if=/dev/zero of=$@ bs=1M count=4096
	echo "2048,,83,*" | sfdisk $@
	sudo losetup -fP $@
	sudo sfdisk /dev/loop0 < partitions.sfdisk
	sudo mkfs.fat -F32 /dev/loop0p2
	sudo mkfs.ext4 -F /dev/loop0p3 -L hypervisor
	mkdir $(BUILDDIR)/mnt
	sudo mount -t ext4 -o loop /dev/loop0p3 $(BUILDDIR)/mnt
	sudo mkdir $(BUILDDIR)/mnt/boot
	sudo mount -o loop /dev/loop0p2 $(BUILDDIR)/mnt/boot
	sudo cp -rv $(ROOT)/{bin,dev,etc,root,home,mnt,media,opt,usr,srv,var,lib,sbin,proc,sys} $(BUILDDIR)/mnt
	sudo rm -f $(ROOT)/boot/boot
	sudo cp -Prv $(ROOT)/boot/* $(BUILDDIR)/mnt/boot
	sudo mount -t proc none $(BUILDDIR)/mnt/proc
	sudo mount -o bind /sys $(BUILDDIR)/mnt/sys
	sudo mknod -m 666 $(BUILDDIR)/mnt/dev/loop0 b 7 0
	sudo mknod -m 666 $(BUILDDIR)/mnt/dev/loop1 b 7 1
	sudo mknod -m 666 $(BUILDDIR)/mnt/dev/loop2 b 7 2
	sudo mknod -m 666 $(BUILDDIR)/mnt/dev/loop3 b 7 3
	sudo rm $(BUILDDIR)/mnt/etc/{hostname,resolv.conf,hosts}
	sudo ln -s /mnt/config/hostname $(BUILDDIR)/mnt/etc/hostname
	sudo ln -s /mnt/config/hosts $(BUILDDIR)/mnt/etc/hosts
	sudo ln -s /mnt/config/resolv.conf $(BUILDDIR)/mnt/etc/resolv.conf
	sudo cp system/fstab $(BUILDDIR)/mnt/etc/fstab
	sudo mkdir -p $(BUILDDIR)/mnt/boot/grub
	echo "(hd0) /dev/loop0" | sudo tee $(BUILDDIR)/mnt/boot/grub/device.map
	sudo chroot $(BUILDDIR)/mnt /usr/sbin/grub-install --target i386-pc -v --boot-directory /boot --modules="ext2 part_gpt" /dev/loop0
	sudo cp grub.cfg $(BUILDDIR)/mnt/boot/grub/grub.cfg
	sudo chmod 777 $(BUILDDIR)/mnt/boot/grub/grub.cfg

	sudo mkdir -p $(BUILDDIR)/mnt/boot/EFI/Boot
	sudo mkdir -p $(BUILDDIR)/mnt/boot/loader/entries
	sudo cp uefi/loader.conf $(BUILDDIR)/mnt/boot/loader/loader.conf
	sudo cp uefi/a.conf $(BUILDDIR)/mnt/boot/loader/entries/a.conf
	sudo cp uefi/b.conf $(BUILDDIR)/mnt/boot/loader/entries/b.conf
	sudo cp $(BUILDDIR)/mnt/usr/lib/gummiboot/gummibootx64.efi $(BUILDDIR)/mnt/boot/EFI/Boot/bootx64.efi

	sudo mkdir -p $(BUILDDIR)/mnt/etc/network
	sudo cp system/interfaces $(BUILDDIR)/mnt/etc/network/interfaces
	-sudo umount $(BUILDDIR)/mnt/proc
	-sudo umount $(BUILDDIR)/mnt/sys
	-sudo umount $(BUILDDIR)/mnt/boot
	-sudo umount $(BUILDDIR)/mnt

chroot: $(BUILDDIR)/tools/apk.static $(PACKAGES) $(REPO)/x86_64/APKINDEX.tar.gz
	@echo MKCHR Creating final chroot
	@mkdir -p $(ROOT)
	sudo $(BUILDDIR)/tools/apk.static -X $(MIRROR)/$(ALPINEVER)/main -U --allow-untrusted --root $(ROOT) --initdb add alpine-base python3 grub grub-bios gummiboot openrc supervisor
	sudo cp -rv $(REPO)/ $(ROOT)/repo
	sudo mknod -m 666 $(ROOT)/dev/full c 1 7
	sudo mknod -m 666 $(ROOT)/dev/ptmx c 5 2
	sudo mknod -m 644 $(ROOT)/dev/random c 1 8
	sudo mknod -m 644 $(ROOT)/dev/urandom c 1 9
	sudo mknod -m 666 $(ROOT)/dev/zero c 1 5
	sudo mknod -m 666 $(ROOT)/dev/tty c 5 0
	echo "nameserver 1.1.1.1" | sudo tee $(ROOT)/etc/resolv.conf
	sudo mkdir -p $(ROOT)/etc/apk
	printf "$(MIRROR)/$(ALPINEVER)/main\n$(MIRROR)/$(ALPINEVER)/community\n/repo" | sudo tee $(ROOT)/etc/apk/repositories
	sudo mount -t proc none $(ROOT)/proc
	sudo mount -o bind /sys $(ROOT)/sys
	sudo env -i chroot $(ROOT) /sbin/apk update --allow-untrusted
	sudo env -i chroot $(ROOT) /sbin/apk add webui linux-hypervisor bcachefs-tools --allow-untrusted
	sudo rm -rf $(ROOT)/repo
	sudo env -i chroot $(ROOT) /sbin/rc-update add devfs sysinit
	sudo env -i chroot $(ROOT) /sbin/rc-update add dmesg sysinit
	sudo env -i chroot $(ROOT) /sbin/rc-update add mdev sysinit
	sudo env -i chroot $(ROOT) /sbin/rc-update add hwclock boot
	sudo env -i chroot $(ROOT) /sbin/rc-update add modules boot
	sudo env -i chroot $(ROOT) /sbin/rc-update add sysctl boot
	sudo env -i chroot $(ROOT) /sbin/rc-update add hostname boot
	sudo env -i chroot $(ROOT) /sbin/rc-update add bootmisc boot
	sudo env -i chroot $(ROOT) /sbin/rc-update add syslog boot
	sudo env -i chroot $(ROOT) /sbin/rc-update add webui boot
	sudo env -i chroot $(ROOT) /sbin/rc-update add mount-ro shutdown
	sudo env -i chroot $(ROOT) /sbin/rc-update add killprocs shutdown
	sudo env -i chroot $(ROOT) /sbin/rc-update add savecache shutdown
	sudo umount $(ROOT)/proc
	sudo umount $(ROOT)/sys

$(REPO)/x86_64/APKINDEX.tar.gz: $(PACKAGES)
	@echo MKIDX Creating APKINDEX for local repo
	@cp $(BUILDCHROOT)/packages/builder/x86_64/APKINDEX.tar.gz $(REPO)/x86_64/APKINDEX.tar.gz

$(REPO)/x86_64/webui-1-r0.apk: $(BUILDCHROOT) APKBUILD
	@echo MKPKG building webui package
	@mkdir -p $(BUILDDIR)/source
	@mkdir -p $(BUILDDIR)/repo/x86_64
	@rm -rf $(BUILDDIR)/source/webui.tar.gz
	@tar -czvf $(BUILDDIR)/source/webui.tar.gz webui/
	sudo rm -rf $(BUILCHROOT)/home/builder/webui
	sudo mkdir -p $(BUILDCHROOT)/home/builder/webui
	sudo cp $(BUILDDIR)/source/webui.tar.gz APKBUILD $(BUILDCHROOT)/home/builder/webui
	sudo chown 1000 -R $(BUILDCHROOT)/home/builder/webui
	sudo env -i chroot --userspec 1000:1000 $(BUILDCHROOT) /bin/sh -c "cd /home/builder/webui && abuild checksum && abuild -r"
	cp $(BUILDCHROOT)/packages/builder/x86_64/webui-1-r0.apk $(REPO)/x86_64/webui-1-r0.apk

.SECONDEXPANSION:
$(REPO)/x86_64/%.apk: | $(BUILDCHROOT)
	@echo MKPKG building $*
	@mkdir -p $(BUILDDIR)/repo/x86_64
	@rm -rf $(BUILDDIR)/home/builder/$(word 1,$(subst -, ,$*))
	sudo cp -rv package/$(word 1,$(subst -, ,$*)) $(BUILDCHROOT)/home/builder/
	sudo chown 1000 -R $(BUILDCHROOT)/home/builder/$(word 1,$(subst -, ,$*))
	sudo env -i $(APATH) chroot --userspec 1000:1000 $(BUILDCHROOT) /bin/sh -c "cd /home/builder/$(word 1,$(subst -, ,$*)) && abuild checksum && abuild -r"
	cp $(BUILDCHROOT)/packages/builder/x86_64/$*.apk $(REPO)/x86_64/$*.apk

$(BUILDCHROOT): $(BUILDDIR)/tools/apk.static
	@echo MKCHR creating buildchroot
	@mkdir -p $(BUILDCHROOT)
	sudo $(BUILDDIR)/tools/apk.static -X $(MIRROR)/$(ALPINEVER)/main -U --allow-untrusted --root $(BUILDCHROOT) --initdb add alpine-base alpine-sdk bash
	sudo mknod -m 666 $(BUILDCHROOT)/dev/full c 1 7
	sudo mknod -m 666 $(BUILDCHROOT)/dev/ptmx c 5 2
	sudo mknod -m 644 $(BUILDCHROOT)/dev/random c 1 8
	sudo mknod -m 644 $(BUILDCHROOT)/dev/urandom c 1 9
	sudo mknod -m 666 $(BUILDCHROOT)/dev/zero c 1 5
	sudo mknod -m 666 $(BUILDCHROOT)/dev/tty c 5 0
	echo "nameserver 1.1.1.1" | sudo tee $(BUILDCHROOT)/etc/resolv.conf
	sudo mkdir -p $(BUILDCHROOT)/etc/apk
	printf "$(MIRROR)/$(ALPINEVER)/main\n$(MIRROR)/$(ALPINEVER)/community" | sudo tee $(BUILDCHROOT)/etc/apk/repositories
	sudo mount -t proc none $(BUILDCHROOT)/proc
	sudo mount -o bind /sys $(BUILDCHROOT)/sys
	sudo env -i chroot $(BUILDCHROOT) /sbin/apk update
	sudo env -i chroot $(BUILDCHROOT) /bin/busybox adduser -D -h /home/builder builder -s /bin/sh
	sudo env -i chroot $(BUILDCHROOT) /bin/busybox addgroup builder abuild
	sudo mkdir -p $(BUILDCHROOT)/home/builder/src
	sudo env -i chroot $(BUILDCHROOT) /bin/sh -c "echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
	sudo env -i $(APATH) chroot --userspec 1000:1000 $(BUILDCHROOT) /usr/bin/abuild-keygen -n -q -a
	sudo cp $(BUILDCHROOT)/.abuild/*.pub $(BUILDCHROOT)/etc/apk/keys
	sudo su -c "cat $(BUILDCHROOT)/.abuild/abuild.conf >> $(BUILDCHROOT)/etc/abuild.conf"
	sudo chmod -R 777 $(BUILDCHROOT)/home/builder
	sudo mkdir -p $(BUILDCHROOT)/packages/builder/x86_64
	sudo cp -rv $(REPO)/x86_64/*.apk $(BUILDCHROOT)/packages/builder/x86_64
	sudo chmod -R 777 $(BUILDCHROOT)/packages

$(BUILDDIR)/tools/apk.static: $(BUILDDIR)/tools/apk-tools-static.apk
	@echo UNTAR build/tools/apk.static
	@tar -xzf "$<" -C "$(BUILDDIR)/tools" --strip-components=1 sbin/apk.static

$(BUILDDIR)/tools/apk-tools-static.apk:
	@echo FETCH build/tools/apk-tools-static.apk
	@mkdir -p $(BUILDDIR)/tools
	@curl $(MIRROR)/$(ALPINEVER)/main/x86_64/apk-tools-static-2.10.3-r1.apk -o "$@" --fail --silent --show-error

clean:
	-rm -rfv $(BUILDDIR)/tools
	-sudo umount $(ROOT)/proc
	-sudo umount $(ROOT)/sys
	-sudo rm -rfv $(ROOT)
	-sudo umount $(BUILDCHROOT)/proc
	-sudo umount $(BUILDCHROOT)/sys
	-sudo rm -rfv $(BUILDCHROOT)
	-rm -rfv $(BUILDDIR)/source
	-sudo umount $(BUILDDIR)/mnt/proc
	-sudo umount $(BUILDDIR)/mnt/sys
	-sudo umount $(BUILDDIR)/mnt/boot
	-sudo umount $(BUILDDIR)/mnt
	-sudo losetup -D
	-rm -rfv $(BUILDDIR)/hypervisor.img
	-sudo rm -rf $(BUILDDIR)/mnt

run: build/hypervisor.img
	@echo RUN   running resulting image...
	qemu-system-x86_64 -m 1024 build/hypervisor.img


.INTERMEDIATE: $(BUILDDIR)/tools/apk-tools-static.apk
.PHONY: clean chroot run
