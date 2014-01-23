#!/bin/sh

HDD=ada0
HDDP0="$ada0"p0
HDDP1="$ada0"p1
HDDP2="$ada0"p2
HDDP3="$ada0"p3
HDDP3ELI="$ada0"p3.eli

# Now that the base system and kernel are installed, we can move our /boot
# folder to it’s final place on the ZFS unencrypted mirror and do a little
# housekeeping:

echo "Cleaning up boot directories"
cd /
mv boot bootdir/
ln -fs bootdir/boot
mv bootdir/encryption.key bootdir/boot/
mv bootdir/*.eli bootdir/boot/

# We need to setup an initial /etc/rc.conf which will mount all ZFS filesystems on boot:
echo "Setting up rc.conf"
echo ‘zfs_enable=”YES”‘ >> /etc/rc.conf
touch /etc/fstab

# And an initial /boot/loader.conf that will load ZFS, encryption and settings
# for encrypted disks on boot:

echo "Setting up /boot/loader.conf"

echo 'vfs.zfs.prefetch_disable="1"' >> /boot/loader.conf
echo 'vfs.root.mountfrom="zfs:zroot"' >> /boot/loader.conf
echo 'zfs_load="YES"' >> /boot/loader.conf
echo 'aesni_load="YES"' >> /boot/loader.conf
echo 'geom_eli_load="YES"' >> /boot/loader.conf
echo "geli_$HDDP3"_keyfile0_load=\"YES\" >> /boot/loader.conf
echo "geli_$HDDP3"_keyfile0_type="\"$HDDP3":geli_keyfile0\" >> /boot/loader.conf
echo "geli_$HDDP3"_keyfile0_name=\"/boot/encryption.key\" >> /boot/loader.conf


# The above settings tell the OS which encryption keyfile to use for each disk
# partition.

#Now you can set your root password:
echo "Now setting root password: "
passwd root

#And configure your timezone:
tzsetup

#And setup a dummy /etc/mail/aliases file to prevent sendmail warnings:

cd /etc/mail
make aliases

#Now you can configure any additional settings you require (such as adding new
#users, configuring networking or setting sshd to run on boot) – when you’re
#done, we need to exit the chroot:

echo "Dropping into shell so you can run last minute configurations"
/bin/sh
