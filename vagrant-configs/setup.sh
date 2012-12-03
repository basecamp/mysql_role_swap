#!/bin/bash

# Disable iptables
echo "Stop firewall..."
service iptables stop 2>&1 >> /dev/null

# Install mysql-server if not already installed
echo "Verify mysql server is installed..."
rpm -q --quiet mysql-server || yum install -y mysql-server

# Start mysqld
echo "Verify mysqld is running..."
service mysqld status 2>&1 >> /dev/null || service mysqld start 2>&1 >> /dev/null

# MySQL user setup
echo "Granting remote root access..."
/usr/bin/mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;"

echo "Granting replication access..."
/usr/bin/mysql -u root -e "GRANT REPLICATION SLAVE ON *.* TO 'slave'@'%' IDENTIFIED BY 'slavepw'; FLUSH PRIVILEGES;"

