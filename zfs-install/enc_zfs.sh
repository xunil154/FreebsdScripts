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


# The Hard Drive to install to
#HDD=ada0
HDD=$1
HDDP0="$HDD"p0
HDDP1="$HDD"p1
HDDP2="$HDD"p2
HDDP3="$HDD"p3
HDDP3ELI="$HDD"p3.eli

echo "Destrotying old disk"
gpart destroy -F $HDD

echo "Creating new gpt partition scheme"
gpart create -s gpt $HDD

echo "Adding base partitions"
gpart create -s gpt $HDD
gpart add -s 128 -t freebsd-boot $HDD
gaprt add -s 3G -t freebsd-zfs $HDD

# create the root partition and disk2 partition
gpart add -t freebsd-zfs $HDD

echo "Installing the bootloader"
# write the bootloader
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $HDD

echo "Setting up temporary ram disk"
# Setup temp ramdisk
mdconfig -a -t malloc -s 128m -u 2
newfs -O2 /dev/md2
mount /dev/md2 /boot/zfs

echo "Loading kernel modules"
# Setup temp ramdisk
# load the kernel modules
kldload opensolaris
kldload zfs
kldload geom_eli

echo "Creating bootdir zpool on /dev/$HDDP2"
# Setup temp ramdisk
# Create initial boot dir
zpool create bootdir /dev/$HDDP2
zpool set bootfs=bootdir bootdir
mkdir /boot/zfs/bootdir
zfs set mountpoint=/boot/zfs/bootdir bootdir
zfs mount bootdir

echo "Generating encryption key"
# generate encryption key
dd if=/dev/random of=/boot/zfs/bootdir/encryption.key bs=4096 count=1

echo "Encrypting the partition"
# encrypt geli partition 
init -b -B /boot/zfs/bootdir/$HDDP3ELI -e AES-XTS -K /boot/zfs/bootdir/encryption.key -l 256 -s 4096 /dev/$HDDP3
echo "Attaching the encrypted partition"
geli attach -k /boot/zfs/bootdir/encryption.key /dev/$HDDP3

echo "Creating zroot pool and remounting bootdir inside zroot"
# Create the zroot pool, and remount the boot dir to inside zroot
zpool create zroot /dev/$HDDP3ELI
zfs set mountpoint=/boot/zfs/zroot zroot
zfs mount zroot
zfs unmount bootdir
mkdir /boot/zfs/zroot/bootdir
zfs set mountpoint=/boot/zfs/zroot/bootdir bootdir
zfs mount bootdir

echo "Creating optimized zfs filesystem"
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
mkdir /boot/zfs/zroot/downloads
cd /boot/zfs/zroot/downloads
fetch $ftp_kernel
fetch $ftp_base
fetch $ftp_src

# Phew, that was a figersore, Now install freebsd
cd /boot/zfs/zroot
echo "Installing base"
unxz -c /boot/zfs/zroot/downloads/base.txz | tar xpf -
echo "Installing kernel"
unxz -c /boot/zfs/zroot/downloads/kernel.txz | tar xpf -
echo "Installing src"
unxz -c /boot/zfs/zroot/downloads/src.txz | tar xpf -

# now set /var/empty to read only
zfs set readonly=on zroot/var/empty

cd /tmp
fetch --no-verify-peer https://raw.github.com/xunil154/FreebsdScripts/master/zfs-install/zfs_chroot.sh
mv zfs_chroot.sh /boot/zfs/zroot/root/

# Now it's time to chroot into the new system!
chroot /boot/zfs/zroot /bin/sh /tmp/zfs_chroot.sh

#Now, we need to make sure the bootloader can read our ZFS pool cache (or it
#wont mount our ZFS disks on boot):

cd /boot/zfs
cp /boot/zfs/zpool.cache /boot/zfs/zroot/boot/zfs/zpool.cache

#Finally, we need to unmount all the ZFS filesystems and configure their final
#mountpoints…
echo "Unmounting and updating zfs mount points"

zfs unmount -a
zfs set mountpoint=legacy zroot
zfs set mountpoint=/tmp zroot/tmp
zfs set mountpoint=/usr zroot/usr
zfs set mountpoint=/var zroot/var
zfs set mountpoint=/bootdir bootdir

echo "Instillation complete. Reboot the system to boot into your new install"
