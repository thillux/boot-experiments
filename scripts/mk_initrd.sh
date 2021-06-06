#!/bin/sh

set -e

INITRD_PATH=$1

cd ${INITRD_PATH}

mknod dev/console c 5 1

find . | cpio -H newc -o | zstd > ../build/${INITRD_PATH}.img.zstd