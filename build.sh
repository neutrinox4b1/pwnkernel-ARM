#!/bin/bash -e

export KERNEL_VERSION=5.4
export BUSYBOX_VERSION=1.32.0
export ARCH=x86_64
export CROSS_COMPILE=x86_64-linux-gnu-

GCC_VER=14
TARGET_CC=x86_64-linux-gnu-gcc-$GCC_VER
HOST_CC=gcc-$GCC_VER

echo "[+] Checking / installing dependencies..."
sudo apt-get -q update
sudo apt-get -q install -y bc bison flex libelf-dev cpio build-essential libssl-dev qemu-system-x86 gcc-$GCC_VER gcc-$GCC_VER-x86-64-linux-gnu

echo "[+] Downloading kernel..."
wget -q -c https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.gz
[ -e linux-$KERNEL_VERSION ] || tar xzf linux-$KERNEL_VERSION.tar.gz

echo "[+] Building kernel..."
make -C linux-$KERNEL_VERSION CC=$TARGET_CC HOSTCC=$HOST_CC defconfig
echo "CONFIG_NET_9P=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_NET_9P_DEBUG=n" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_9P_FS=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_9P_FS_POSIX_ACL=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_9P_FS_SECURITY=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_NET_9P_VIRTIO=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_PCI=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_BLK=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_BLK_SCSI=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_NET=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_CONSOLE=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_HW_RANDOM_VIRTIO=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_DRM_VIRTIO_GPU=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_PCI_LEGACY=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_BALLOON=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_VIRTIO_INPUT=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_CRYPTO_DEV_VIRTIO=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_BALLOON_COMPACTION=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_PCI=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_PCI_HOST_GENERIC=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_GDB_SCRIPTS=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_DEBUG_INFO=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_DEBUG_INFO_REDUCED=n" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_DEBUG_INFO_SPLIT=n" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_DEBUG_FS=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_DEBUG_INFO_DWARF4=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_DEBUG_INFO_BTF=y" >> linux-$KERNEL_VERSION/.config
echo "CONFIG_FRAME_POINTER=y" >> linux-$KERNEL_VERSION/.config

sed -i 'N;s/WARN("missing symbol table");\n\t\treturn -1;/\n\t\treturn 0;\n\t\t\/\/ A missing symbol table is actually possible if its an empty .o file.  This can happen for thunk_64.o./g' linux-$KERNEL_VERSION/tools/objtool/elf.c

sed -i 's/unsigned long __force_order/\/\/ unsigned long __force_order/g' linux-$KERNEL_VERSION/arch/x86/boot/compressed/pgtable_64.c

sed -i '/^extern size_t strlcpy(char \*dest, const char \*src, size_t size);$/d' linux-$KERNEL_VERSION/tools/include/linux/string.h

sed -i 's/-Werror//g' linux-$KERNEL_VERSION/tools/lib/subcmd/Makefile
sed -i 's/-Werror//g' linux-$KERNEL_VERSION/tools/objtool/Makefile

make -C linux-$KERNEL_VERSION CC=$TARGET_CC HOSTCC=$HOST_CC olddefconfig
make -C linux-$KERNEL_VERSION CC=$TARGET_CC HOSTCC=$HOST_CC -j$(nproc) bzImage

echo "[+] Downloading busybox..."
wget -q -c https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
[ -e busybox-$BUSYBOX_VERSION ] || tar xjf busybox-$BUSYBOX_VERSION.tar.bz2

echo "[+] Building busybox..."
make -C busybox-$BUSYBOX_VERSION CC=$TARGET_CC HOSTCC=$HOST_CC defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' busybox-$BUSYBOX_VERSION/.config
sed -i 's/^CONFIG_TC=y/# CONFIG_TC is not set/' busybox-$BUSYBOX_VERSION/.config
make -C busybox-$BUSYBOX_VERSION CC=$TARGET_CC HOSTCC=$HOST_CC -j$(nproc)
make -C busybox-$BUSYBOX_VERSION CC=$TARGET_CC HOSTCC=$HOST_CC install

echo "[+] Building filesystem..."
cd fs
mkdir -p bin sbin etc proc sys usr/bin usr/sbin root home/ctf
cd ..
cp -a busybox-$BUSYBOX_VERSION/_install/* fs

echo "[+] Building modules..."
cd src
make CC=$TARGET_CC HOSTCC=$HOST_CC
cd ..
cp src/*.ko fs/
