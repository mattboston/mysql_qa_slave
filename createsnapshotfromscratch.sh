#!/bin/sh
# Copyright 2006 Matthew Shields matt@mattshields.org

# this script creates LVM snapshots from scratch on the qadbm:3306 and qadbs:3306 mysql instances
######
#
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
service mysql-main start

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

mysql --host=10.5.132.17 --port=3306 -e 'stop slave ; change master to master_host="10.5.132.16", master_log_file="qadbm-3306-bin.000001", master_log_pos=4, master_user="repl", master_password="vic20-sonned$$";'

# start slave
echo "start slave"
mysql --host=10.5.132.17 --port=3306 -e "start slave;"
