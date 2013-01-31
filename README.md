mysql_qa_slave
==============

These scripts allow you to have a QA server that is a MySQL slave of your production database which runs on port 3307 (hidden from users), then you have LVM managing snapshots of this database which allow you to create a QA master and slave on the same server (using 2 different IPs) so you can have instant snapshots of production data in QA.


For this to work, you need to know how large your database is (ie. 500GB), how much data changes on your slave to production, QA master and QA slave, and how long between re-snapshotting.  When I used this I had a 2TB volume, that I had allocated 1TB to 3307, then used the 1TB unallocated space as LVM snapshot space.  This volume has to be a separate volume from your OS.

Here is the layout I used for the QA server

# mysql servers on qadbm
mysql			10.5.132.16:3306 (QA Master)
mysql-slave		10.5.132.17:3306 (QA Slave)
mysql-copy		10.5.132.16:3307 (Slave of production)

Volume / OS
Volume 1TB /dev/mapper/vg.db-lv.db mounted as /var/lib/mysql-copy/data (slave of production 3307)
Volume /dev/mapper/vg.db-db.snapshot1 snapshot mounted as /var/lib/mysql/data (QA master, snapshot of 3307)
Volume /dev/mapper/vg.db-db.snapshot2 snapshot mounted as /var/lib/mysql-slave/data (QA slave, snapshot of 3307)


