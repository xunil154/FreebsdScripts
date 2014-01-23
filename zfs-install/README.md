Encrypted ZFS
=============
This directory contains scripts to install Freebsd 10.0-RELEASE onto an
encrypted zfs file system.

It will partition the disks as such:

ada0p1: 128k 
ada0p2: 3GB <- Boot directory
ada0p3: Remaining space <- Will be encrypted


Setup instructions
1) Insert the FreeBSD 10-RELEASE disk
2) Boot into the 'Live OS'
3) Connect to the network
```
# dhclient em0
# mkdir -p /tmp/bsdinstall_tmp
# echo 'nameserver 8.8.8.8' > /tmp/bsdinstall_tmp/resolv.conf
```

4) Download this script
```
$ cd && fetch https://raw.github.com/xunil154/FreebsdScripts/master/zfs-install/enc_zfs.sh
```

5) Run this script
```
$ chmod +x enc_zfs.sh && ./enc_zfs.sh ada0
```
