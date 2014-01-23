#!/bin/sh

# Roughly following instructions from:
# http://www.dan.me.uk/blog/2012/05/06/full-disk-encryption-with-zfs-root-for-freebsd-9-x/


####################################
# Freebsd Encrypted ZFS setup script
# Version 0.1
####################################

####################################
# Setup instructions
# 1) Insert the FreeBSD 10-RELEASE disk
# 2) Boot into the 'Live OS'
# 3) Download this script
#   $ cd && fetch https://raw.github.com/xunil154/FreebsdScripts/master/zfs-install/enc_zfs.sh
# 4) Run this script
#   $ chmod +x enc_zfs.sh && ./enc_zfs.sh ada0
####################################


if [ $# -ne 1 ]
    then
    echo "Usage: $0 <hdd lable>"
    echo " eg: $0 ada0"
    exit 1
fi

die(){
    echo "**** $1"
    exit 1
}


# The Hard Drive to install to
#HDD=ada0
HDD=$1
HDDP0="$HDD"p0
HDDP1="$HDD"p1
HDDP2="$HDD"p2
HDDP3="$HDD"p3
HDDP3ELI="$HDD"p3.eli

echo "**********************************************************"
echo "WARNING: Running this script will destroy ALL data on $HDD"
echo "**********************************************************"
read -p "Do you wish to continue? (Y/N): " yn
case $yn in
    [Yy]* ) echo "Alrighty then, here we go";;
    [Nn]* ) exit 1;;
    * ) echo "Invalid option, assuming NO"; exit 1;;
esac
sleep 5

echo "Destrotying old disk"
echo "----------------------------------------------------"
gpart destroy -F $HDD

echo "Creating new gpt partition scheme"
echo "----------------------------------------------------"
if ! gpart create -s gpt $HDD
    then
    die "Could not create gpt partition"
fi

echo "Adding base partitions"
echo "----------------------------------------------------"
if ! gpart add -s 128 -t freebsd-boot $HDD
    then
    die "could not create boot fs"
fi
if ! gpart add -s 3G -t freebsd-zfs $HDD
    then
    die "could not create boot partition"
fi

# create the root partition and disk2 partition
if ! gpart add -t freebsd-zfs $HDD
    then
    die "could not create main root partition"
fi

echo "Installing the bootloader"
echo "----------------------------------------------------"
# write the bootloader
if ! gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $HDD
    then
    die "Failed to install bootloader"
fi

echo "Setting up temporary ram disk"
echo "----------------------------------------------------"
# Setup temp ramdisk
mdconfig -a -t malloc -s 128m -u 2
newfs -O2 /dev/md2
mount /dev/md2 /boot/zfs

echo "Loading kernel modules"
echo "----------------------------------------------------"
# Setup temp ramdisk
# load the kernel modules
if ! kldload opensolaris
    then
    die "Could not load opensolaris module"
fi
if ! kldload zfs
    then
    die "Could not load zfs module"
fi
if ! kldload geom_eli
    then
    die "Could not load geom_eli module"
fi

echo "Creating bootdir zpool on /dev/$HDDP2"
echo "----------------------------------------------------"
# Setup temp ramdisk
# Create initial boot dir
if ! mkdir -p /boot/zfs/bootdir
    then
    die "Could not create /boot/zfs/bootdir "
fi

# Should error that it cannot mount to /bootdir
zpool create bootdir /dev/$HDDP2

if ! zpool set bootfs=bootdir bootdir
    then
    die "Could not set bootfs param on bootdir"
fi
if ! zfs set mountpoint=/boot/zfs/bootdir bootdir
    then
    die "Could not set mountpoint for bootdir"
fi
if ! zfs mount bootdir
    then
    die "Could not create mount bootdir pool"
fi

echo "Generating encryption key"
echo "----------------------------------------------------"
# generate encryption key
dd if=/dev/random of=/boot/zfs/bootdir/encryption.key bs=4096 count=1

echo "Encrypting the partition"
echo "----------------------------------------------------"
echo 
echo "Enter the disk encryption password: "
# encrypt geli partition 
if ! geli init -b -B /boot/zfs/bootdir/$HDDP3ELI -e AES-XTS -K /boot/zfs/bootdir/encryption.key -l 256 -s 4096 /dev/$HDDP3
    then
    die "Failed to encrypt $HDDP3"
fi
echo "Attaching the encrypted partition"
echo "----------------------------------------------------"
if ! geli attach -k /boot/zfs/bootdir/encryption.key /dev/$HDDP3
    then
    die "Could not attach encrypted partition $HDDP3"
fi

sleep 4

echo "Creating zroot pool and remounting bootdir inside zroot"
echo "----------------------------------------------------"
# Create the zroot pool, and remount the boot dir to inside zroot

# expect this to error, /zroot does not exist so it cannot be mounted
zpool create zroot /dev/$HDDP3ELI

if ! zfs set mountpoint=/boot/zfs/zroot zroot
    then
    die "Could not set zroot mount point"
fi
zfs mount zroot
zfs unmount bootdir
mkdir -p /boot/zfs/zroot/bootdir
zfs set mountpoint=/boot/zfs/zroot/bootdir bootdir
if ! zfs mount bootdir
    then
    die "Could not remount bootdir inside zroot"
fi

echo "Creating optimized zfs filesystem"
echo "----------------------------------------------------"
# Create the sub pools optimized for each data type
zfs set checksum=fletcher4 zroot
zfs create -o compression=on -o exec=on -o setuid=off zroot/tmp

chmod 1777 /boot/zfs/zroot/tmp

zfs create zroot/usr
zfs create zroot/usr/home
cd /boot/zfs/zroot; ln -s /usr/home home

zfs create -o compression=lzjb -o setuid=off zroot/usr/ports
zfs create -o compression=off -o exec=off -o setuid=off zroot/usr/ports/distfiles
zfs create -o compression=off -o exec=off -o setuid=off zroot/usr/ports/packages

zfs create zroot/var
zfs create -o compression=lzjb -o exec=off -o setuid=off zroot/var/crash
zfs create -o exec=off -o setuid=off zroot/var/db

zfs create -o compression=lzjb -o exec=on -o setuid=off zroot/var/db/pkg
zfs create -o exec=off -o setuid=off zroot/var/empty

zfs create -o compression=lzjb -o exec=off -o setuid=off zroot/var/log
zfs create -o compression=gzip -o exec=off -o setuid=off zroot/var/mail

zfs create -o exec=off -o setuid=off zroot/var/run
zfs create -o compression=lzjb -o exec=on -o setuid=off zroot/var/tmp
zfs create -V 2G -o org.freebsd:swap=on -o checksum=off -o compression=off -o dedup=off -o sync=disabled -o primarycache=none zroot/swap
chmod 1777 /boot/zfs/zroot/var/tmp


arch=$(uname -p)
release="10.0-RELEASE"
ftp="ftp://ftp.freebsd.org/pub/FreeBSD/releases/$arch/$release"
ftp_kernel=$ftp"/kernel.txz"
ftp_base=$ftp"/base.txz"
ftp_src=$ftp"/src.txz"

echo "Detected arch: $arch"
echo "Installing freebsd: Will download the latest images from $ftp"
echo "----------------------------------------------------"
mkdir -p /boot/zfs/zroot/downloads
cd /boot/zfs/zroot/downloads
if ! fetch $ftp_kernel
    then
    die "Could not retrieve kernel code"
fi
if ! fetch $ftp_base
    then
    die "Could not retrieve freebsd base"
fi
if ! fetch $ftp_src
    then
    die "Could not retrieve freebsd src"
fi

# Phew, that was a figersore, Now install freebsd
cd /boot/zfs/zroot
echo "Installing base"
echo "----------------------------------------------------"
if ! unxz -c /boot/zfs/zroot/downloads/base.txz | tar xpf -
    then
    die "Failed to install base"
fi
echo "Installing kernel"
echo "----------------------------------------------------"
if ! unxz -c /boot/zfs/zroot/downloads/kernel.txz | tar xpf -
    then
    die "Failed to install base"
fi
echo "Installing src"
echo "----------------------------------------------------"
if ! unxz -c /boot/zfs/zroot/downloads/src.txz | tar xpf -
    then
    echo "Failed to install src, but continuing anyway"
fi

echo "Cleanup"
echo "----------------------------------------------------"
rm -rf /boot/zfs/zroot/downloads

# now set /var/empty to read only
zfs set readonly=on zroot/var/empty

cd /tmp
fetch --no-verify-peer https://raw.github.com/xunil154/FreebsdScripts/master/zfs-install/zfs_chroot.sh
mkdir -p /boot/zfs/zroot/root/
mv zfs_chroot.sh /boot/zfs/zroot/root/

# Now it's time to chroot into the new system!
chroot /boot/zfs/zroot /bin/sh /root/zfs_chroot.sh $HDD

#Now, we need to make sure the bootloader can read our ZFS pool cache (or it
#wont mount our ZFS disks on boot):

cd /boot/zfs
cp /boot/zfs/zpool.cache /boot/zfs/zroot/boot/zfs/zpool.cache

#Finally, we need to unmount all the ZFS filesystems and configure their final
#mountpoints…
echo "Unmounting and updating zfs mount points"
echo "----------------------------------------------------"

zfs unmount -a
zfs set mountpoint=legacy zroot
zfs set mountpoint=/tmp zroot/tmp
zfs set mountpoint=/usr zroot/usr
zfs set mountpoint=/var zroot/var
zfs set mountpoint=/bootdir bootdir

echo "Instillation complete. Reboot the system to boot into your new install"
