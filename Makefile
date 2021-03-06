APK := apk/apk.static
APK_OPTS := --repositories-file apk/repositories -U --allow-untrusted --no-scripts
KERNEL_VERSION := 5.13.10
NUM_CORES := $(shell nproc)

EFI_KEY_CN_PREFIX = Test
EFI_GUID := $(shell python3 -c 'import uuid; print(str(uuid.uuid1()))')

# use kernel_modules here, if you build with modules
all: build initrd_inst initrd_bt intel_ucode kernel ptgen_bin image

clean:
	rm -rf \
		build \
		initrd_inst initrd_boot intel_ucode \
		linux \
		*.key \
		*.cer \
		*.crt

build:
	mkdir -p build/efi/boot/

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

linux:
	git clone --depth=1 --branch v$(KERNEL_VERSION) https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

kernel: linux
	cp configs/kernel-config linux/.config
	$(MAKE) -C linux olddefconfig
	$(MAKE) -C linux -j$(NUM_CORES)
	cp linux/arch/x86_64/boot/bzImage build/bzImage

kernel_modules: kernel initrd_inst initrd_bt
	$(MAKE) -C linux INSTALL_MOD_PATH="$(CURDIR)/initrd_inst" modules_install
	$(MAKE) -C linux INSTALL_MOD_PATH="$(CURDIR)/initrd_boot" modules_install

intel_ucode:
	git clone --depth=1 https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files intel_ucode
	/sbin/iucode_tool -v --write-earlyfw=$(CURDIR)/build/intel-ucode.img intel_ucode/intel-ucode

init_bin: linuxrc/src/main.rs
	cargo install --target x86_64-unknown-linux-musl --path linuxrc --root $(CURDIR)/build/

efi-keys:
	openssl req -new -x509 -newkey rsa:4096 -subj "/CN=$(EFI_KEY_CN_PREFIX) PK/" -keyout PK.key -out PK.crt -days 3650 -nodes -sha256
	openssl req -new -x509 -newkey rsa:4096 -subj "/CN=$(EFI_KEY_CN_PREFIX) KEK/" -keyout KEK.key -out KEK.crt -days 3650 -nodes -sha256
	openssl req -new -x509 -newkey rsa:4096 -subj "/CN=$(EFI_KEY_CN_PREFIX) DB/" -keyout DB.key -out DB.crt -days 3650 -nodes -sha256
	openssl x509 -in PK.crt -out PK.cer -outform DER
	openssl x509 -in KEK.crt -out KEK.cer -outform DER
	openssl x509 -in DB.crt -out DB.cer -outform DER
	cert-to-efi-sig-list -g $(EFI_GUID) PK.crt PK.esl
	cert-to-efi-sig-list -g $(EFI_GUID) KEK.crt KEK.esl
	cert-to-efi-sig-list -g $(EFI_GUID) DB.crt DB.esl
	sign-efi-sig-list -t "$(shell date --date='1 second' +'%Y-%m-%d %H:%M:%S')" -k PK.key -c PK.crt PK PK.esl PK.auth
	chmod 0600 *.key

ptgen_bin: ptgen/ptgen.c ptgen/crc32.c ptgen/crc32.h
	$(CC) $(CFLAGS) -DWANT_ALTERNATE_PTABLE=1 -o build/ptgen ptgen/ptgen.c ptgen/crc32.c

image: init_bin
	cp build/bin/linuxrc initrd_install/init
	cp build/bin/linuxrc initrd_boot/init
	fakeroot scripts/mk_initrd.sh initrd_install
	fakeroot scripts/mk_initrd.sh initrd_boot
	python3 scripts/createImage.py

vm-bios:
	qemu-system-x86_64 \
		-machine q35,accel=kvm \
		-m 1024 \
		-smp 2 \
		-cpu host \
		-net none \
		-drive file=build/image_install.raw,format=raw,if=virtio

vm-efi:
	qemu-system-x86_64 \
		-machine q35 \
		--enable-kvm \
		-m 1024 \
		-smp 2 \
		-cpu host \
		-device virtio-gpu-pci \
		-serial stdio \
		-drive file=build/image_install.raw,format=raw,if=virtio \
		-drive if=pflash,format=raw,readonly=on,file=/usr/share/ovmf/OVMF.fd \
		-net none
