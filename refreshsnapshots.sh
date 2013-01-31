#!/bin/sh
# Copyright 2006 Matthew Shields matt@mattshields.org

# this script refreshes LVM snapshots on the qadbm:3306 and qadbs:3306 mysql instances
######
#
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

# stop 3307:slave
echo "stopping mysql-copy"
service mysql-copy stop

echo "creating db.snapshot1"
lvcreate -s -n db.snapshot1 -L 500G /dev/vg.db/lv.db

echo "creating db.snapshot2"
lvcreate -s -n db.snapshot2 -L 500G /dev/vg.db/lv.db

# start 3307:slave
echo "starting mysql-copy"
service mysql-copy start

# mount snapshot1
echo "mounting snapshot1"
mount /dev/mapper/vg.db-db.snapshot1 /var/lib/mysql/data

# mount snapshot2
echo "mounting snapshot2"
mount /dev/mapper/vg.db-db.snapshot2 /var/lib/mysql-slave/data

# remove mysql - files not needed for qadbm
rm -rf /var/lib/mysql/data/relay-log.info /var/lib/mysql/data/master.info /var/lib/mysql/data/qadbm-relay-bin.* /var/lib/mysql/qadbm-3306.err /var/lib/mysql-slave/qadbm-slave-3306.err

# remove InnoDB logs
rm -rf /var/lib/mysql/data/ib_logfile* /var/lib/mysql-slave/data/ib_logfile*

# start 3306
echo "starting mysql"
service mysql start

# change master to master_host=""; // just to be safe
echo "change master to master_host=\"\";"
mysql --host=10.5.132.16 --port=3306 -e 'change master to master_host="";'

# reset master // resets the binary logs
echo "reset master"
# dont' run the following unless you want to delete the binary logs
mysql --host=10.5.132.16 --port=3306 -e 'reset master;'

# service mysql-slave start
#########  
#  remove /var/lib/mysql-slave/data/master.info because start slave is set in 
# the my.conf so the mysql-slave doesn't "start slave" based on repl-master 
# and possibly process some sql before the stop slave later on. without the 
# master.info "start slave won't start cause it doesn't know who the master is"
# this is also an issue with the mysql.conf files 
echo "removing /var/lib/mysql-slave/data/master.info"
#rm -rf /var/lib/mysql-slave/data/master.info
rm -rf /var/lib/mysql-slave/data/relay-log.info /var/lib/mysql-slave/data/master.info /var/lib/mysql-slave/data/qadbm-relay-bin.*
echo "starting mysql-slave"
service mysql-slave start

# mysql --host=10.5.132.17 --port=3306
# change master to master_host="10.5.132.16", master_log_file="qadbm-3306-bin.000001", master_log_pos=4;
echo "stop slave ; change master to master_host=\"10.5.132.16\", master_log_file=\"qadbm-3306-bin.000001\", master_log_pos=4;";

mysql --host=10.5.132.17 --port=3306 -e 'stop slave ; change master to master_host="10.5.132.16", master_log_file="qadbm-bin.000001", master_log_pos=4, master_user="repl", master_password="vic20-sonned$$";'

# change all users on slave to read-only
echo "change all slave users to read-only permissions"

mysql -S /var/lib/mysql-slave/mysql.sock mysql -e "UPDATE user SET Select_priv='Y',Insert_priv='N',Update_priv='N',Delete_priv='N',Create_priv='N',Drop_priv='N',Reload_priv='N',Shutdown_priv='N',Process_priv='N',File_priv='N',Grant_priv='N',References_priv='N',Index_priv='N',Alter_priv='N',Show_db_priv='N',Super_priv='N',Create_tmp_table_priv='N',Lock_tables_priv='N',Execute_priv='N',Repl_slave_priv='N',Repl_client_priv='N' WHERE User NOT IN ('dbadmin','repl');"

# start slave
echo "start slave"
mysql --host=10.5.132.17 --port=3306 -e "start slave;"
