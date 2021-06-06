APK := apk/apk.static
APK_OPTS := --repositories-file apk/repositories -U --allow-untrusted --initdb

all: initrd_inst initrd_bt

clean:
	rm -rf initrd_install initrd_boot

initrd_install_dir:
	mkdir -p initrd_install

initrd_boot_dir:
	mkdir -p initrd_boot

initrd_inst: initrd_install_dir
	$(APK) $(APK_OPTS) -p initrd_install add \
		lvm2 \
		dosfstools \
		e2fsprogs \
		gptfdisk

initrd_bt: initrd_boot_dir
	$(APK) $(APK_OPTS) -p initrd_boot add \
		lvm2
