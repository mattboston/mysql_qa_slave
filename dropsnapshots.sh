#!/bin/sh
# Copyright 2006 Matthew Shields matt@mattshields.org

# this script drops LVM snapshots on the qadbm:3306 and qadbs:3306 mysql instances
######
# stop 3306:slave
echo "stopping mysql-slave"
service mysql-slave stop

# stop 3306
echo "stopping mysql"
service mysql stop

# unmount snapshot1
echo "unmounting snapshot1"
umount /var/lib/mysql/data

# unmount snapshot2
echo "unmounting snapshot2"
umount /var/lib/mysql-slave/data

# test to see if snapshot1 and snapshot2 are unmounted, exit if still mounted.
mounted=0;

one=`df | grep /var/lib/mysql/data`;
if [ ! -z "$one" ]; then
        echo "/var/lib/mysql/data is still mounted"
        mounted=1;
fi

two=`df | grep /var/lib/mysql-slave/data`;
if [ ! -z "$two" ]; then
        echo "/var/lib/mysql-slave/data is still mounted"
        mounted=1;
fi
if [ $mounted == "1" ]; then
        echo "something wasn't unmounted, please unmount the two snapshots by hand and re-run this script."
	echo " exiting"
        exit
else
        echo "both snapshots are unmounted. continue"
fi


# remove snapshot1
echo "removing snapshot1"
lvremove -f /dev/vg.db/db.snapshot1 

# remove snapshot2
echo "removing snapshot2"
lvremove -f /dev/vg.db/db.snapshot2 






