#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-
TOOLCHAIN_PATH=/home/user/arm-gnu-toolchains/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu
WRITER_SOURCE_DIR="$PWD"

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    # first do the deep clean
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper

    # configure for virt arm dev board
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    
    # build a kernel image
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all

    # build a kernel modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules

    # build a kernel device tree
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs

fi

echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    #sudo rm  -rf ${OUTDIR}/rootfs
    rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir rootfs
cd rootfs

mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var init
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox

    make distclean
    make defconfig
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
    make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

else
    cd busybox
    make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install
fi


echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs

# program interpreter
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox 2>&1 |
awk '/program interpreter/ {
   gsub(/\]$/, "", $4)
    sub(".*/", "", $4)
    print $4
}' |
while IFS= read -r interp; do
    find "$TOOLCHAIN_PATH" -iname "$interp" -exec cp -v {} ${OUTDIR}/rootfs/lib \;
    #sudo chown root:root ${OUTDIR}/rootfs/lib/"$interp"
done

# Shared library
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox 2>&1 |
awk '/Shared library/ {
    gsub(/^\[/, "", $5)    # remove leading [
    gsub(/\]$/, "", $5)    # remove trailing ]
    sub(".*/", "", $5)     # remove any path before the filename
    print $5
}' |
while IFS= read -r sharedLib; do
    find "$TOOLCHAIN_PATH" -iname "$sharedLib" -exec cp -v {} ${OUTDIR}/rootfs/lib64 \;
    #sudo chown root:root ${OUTDIR}/rootfs/lib64/"$sharedLib"
done

# TODO: Make device nodes
cd "$OUTDIR"/rootfs

#sudo mknod -m 666 dev/null c 1 3
#sudo mknod -m 666 dev/ttAMA0 c 5 1 
#sudo mknod -m 666 dev/console c 5 1 
#sudo mknod -m 666 dev/tty c 5 0

# TODO: Clean and build the writer utility
cd "$WRITER_SOURCE_DIR"
make CROSS_COMPILE=${CROSS_COMPILE}


# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp writer "$OUTDIR"/rootfs/home/
cp autorun-qemu.sh "$OUTDIR"/rootfs/home
#sudo chmod +x "$OUTDIR"/rootfs/home/autorun-qemu.sh

cp -r conf/ "$OUTDIR"/rootfs/home/
cp finder-test.sh "$OUTDIR"/rootfs/home/
cp finder.sh  "$OUTDIR"/rootfs/home/


# TODO: Chown the root directory
cd "$OUTDIR"/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio 

# Copy Image to OUTDIR
cp -f "$OUTDIR"/linux-stable/arch/arm64/boot/Image "$OUTDIR"

# TODO: Create initramfs.cpio.gz
echo "$PWD"
echo Running gzip for initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio
