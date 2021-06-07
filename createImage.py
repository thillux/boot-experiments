#!/usr/bin/env python3

import subprocess
from jinja2 import Environment, Template, FileSystemLoader
import os
import sys
from functools import reduce

def round_to_next(n, mult):
    return ((n + mult - 1) // mult + 1) * mult

env = Environment(loader=FileSystemLoader('configs'))

gpt_out = "build/image_install.raw"

image_files = [
    "build/efi/boot/bootx64.efi",
    "build/intel-ucode.img",
    "build/initrd_install.img.zstd",
    "build/bzImage"
]

# check size
subprocess.check_call(f"grub-mkstandalone -O x86_64-efi -o build/efi/boot/bootx64.efi", shell=True)
image_size = reduce(lambda x,y: x+y, map(lambda x: os.path.getsize(x), image_files))

# image should be large enough to hold FAT32
image_size = max(40 * 1024 * 1024, image_size)
# add 10% slack, round to block size
image_size = round_to_next(int(image_size * 1.1), 512)

subprocess.check_call(f"build/ptgen -g -v -l 2048 -o {gpt_out} -t 0xef -p {image_size // 1024}", shell=True)
subprocess.check_call(f"dd if=/dev/zero of=efi bs=512 count={image_size // 512}", shell=True)
subprocess.check_call(f"/sbin/mkfs.vfat -F32 efi", shell=True)

fsuuid_efi = subprocess.check_output(f"/sbin/blkid -s UUID -o value efi", shell=True)
fsuuid_efi = str(fsuuid_efi, 'utf-8').strip()

grub_tmpl = env.get_template('grub_live.cfg.j2')
grub_tmpl.stream(fs_uuid=fsuuid_efi,initrd="initrd_install.img.zstd").dump("build/grub_live.cfg")
subprocess.check_call(f"grub-mkstandalone -O x86_64-efi -o build/efi/boot/bootx64.efi boot/grub/grub.cfg=build/grub_live.cfg", shell=True)

subprocess.check_call(f"mcopy -s -i efi build/efi ::", shell=True)
subprocess.check_call(f"mcopy -s -i efi build/bzImage ::", shell=True)
subprocess.check_call(f"mcopy -s -i efi build/intel-ucode.img ::", shell=True)
subprocess.check_call(f"mcopy -s -i efi build/initrd_install.img.zstd ::", shell=True)

subprocess.check_call(f"dd if=efi of={gpt_out} bs=512 seek={round_to_next(33, 2048)} conv=notrunc", shell=True)
