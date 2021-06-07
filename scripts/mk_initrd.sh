#!/bin/sh

set -e

INITRD_PATH=$1

cd ${INITRD_PATH}

mknod dev/console c 5 1

find . -mindepth 1 | cpio -o -H newc | zstd > ../build/${INITRD_PATH}.img.zstd