APK := apk/apk.static
APK_OPTS := --repositories-file apk/repositories -U --allow-untrusted --no-scripts
KERNEL_VERSION := 5.12.9
NUM_CORES := $(shell nproc)

all: build initrd_inst initrd_bt

clean:
	rm -rf build initrd_install initrd_boot linux

build:
	mkdir -p build

initrd_install_dir:
	mkdir -p initrd_install

initrd_boot_dir:
	mkdir -p initrd_boot

initrd_inst: build initrd_install_dir
	$(APK) $(APK_OPTS) --initdb -p initrd_install add \
		lvm2 \
		dosfstools \
		e2fsprogs \
		gptfdisk \
		kmod
	# force uninstall of busybox not possible, do it manually
	(cd initrd_install && \
	rm -f \
	   bin/busybox \
	   bin/sh \
	   etc/logrotate.d/acpid \
	   etc/network/if-up.d/dad \
	   etc/securetty \
	   etc/udhcpd.conf \
	   usr/share/udhcpc/default.script)
	(cd initrd_install && \
	 find . | cpio -H newc -o > ../build/initrd_install.img)

initrd_bt: build initrd_boot_dir
	$(APK) $(APK_OPTS) --initdb -p initrd_boot add \
		lvm2 \
		bash
	# force uninstall of busybox not possible, do it manually
	(cd initrd_boot && \
	rm -f \
	   bin/busybox \
	   bin/sh \
	   etc/logrotate.d/acpid \
	   etc/network/if-up.d/dad \
	   etc/securetty \
	   etc/udhcpd.conf \
	   usr/share/udhcpc/default.script)
	(cd initrd_boot && \
	 find . | cpio -H newc -o > ../build/initrd_boot.img)

linux:
	git clone --depth=1 --branch v$(KERNEL_VERSION) https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

kernel: linux
	cp configs/kernel-config linux/.config
	(cd linux && make olddefconfig && make -j$(NUM_CORES))
