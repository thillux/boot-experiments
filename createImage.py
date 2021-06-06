#!/usr/bin/env python3

import subprocess

disk_size = 40 * 1024 * 1024

gpt_out = "gpt"

subprocess.check_call(f"build/ptgen -g -v -l 2048 -o {gpt_out} -t 0xef -p {disk_size // 1024} -t 0x83 -N \"Linux Filesystem\" -p {disk_size // 1024}", shell=True)
subprocess.check_call(f"dd if=/dev/zero of=efi bs=1M count=40", shell=True)
subprocess.check_call(f"dd if=/dev/zero of=ext2 bs=1M count=40", shell=True)
subprocess.check_call(f"mkfs.vfat -F32 efi", shell=True)
subprocess.check_call(f"mkfs.ext2 ext2", shell=True)

fsuuid_efi = subprocess.check_output(f"blkid -s UUID -o value efi", shell=True)
fsuuid_ext2 = subprocess.check_output(f"blkid -s UUID -o value ext2", shell=True)
ptuuid_ext2 = "5452574f-2211-4433-5566-778899aabb02"

with open("grub.cfg", "w+") as g:
    g.write(f"loadfont unicode\n")
    g.write(f"set gfxmode=auto\n")
    g.write(f"insmod all_video\n")
    g.write(f"insmod gfxterm\n")
    g.write(f"\n")
    g.write(f"terminal_input console\n")
    g.write(f"terminal_output gfxterm\n")
    g.write(f"\n")
    g.write(f"insmod gzio\n")
    g.write(f"insmod part_gpt\n")
    g.write(f"insmod ext2\n")
    g.write(f"\n")
    g.write(f"set color_normal=light-gray/black\n")
    g.write(f"set menu_color_normal=light-gray/blue\n")
    g.write(f"set menu_color_highlight=light-gray/light-red\n")
    g.write(f"\n")
    g.write(f"set timeout_style=menu\n")
    g.write(f"set timeout=5\n")
    g.write(f"\n")
    g.write(f"menuentry 'Linux' {{\n")
    g.write(f"  set gfxpayload=keep\n")
    g.write(f"  search --no-floppy --set=root --fs-uuid {str(fsuuid_ext2, 'utf-8').strip()}\n")
    g.write(f"  linux /bzImage\n")
    g.write(f"  initrd /intel-ucode.img /initramfs.img\n")
    g.write(f"}}\n")
    g.flush()

subprocess.check_call(f"grub-mkstandalone -O x86_64-efi -o dst/boot/efi/boot/bootx64.efi boot/grub/grub.cfg=grub.cfg", shell=True)

subprocess.check_call(f"mcopy -s -i efi dst/boot/efi ::", shell=True)
subprocess.check_call(f"e2cp dst/boot/bzImage ext2:bzImage", shell=True)
subprocess.check_call(f"e2cp initramfs.img ext2:initramfs.img", shell=True)
subprocess.check_call(f"e2cp intel-ucode.img ext2:intel-ucode.img", shell=True)

offset_0 = ((33 + 2047) // 2048 + 1) * 2048
offset_1 = ((disk_size // 512 + 33 + 2047) // 2048 + 1) * 2048

print(offset_0, offset_1)

subprocess.check_call(f"dd if=efi of=gpt bs=512 seek={offset_0} conv=notrunc", shell=True)
subprocess.check_call(f"dd if=ext2 of=gpt bs=512 seek={offset_1} conv=notrunc", shell=True)
