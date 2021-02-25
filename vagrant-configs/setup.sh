#!/bin/bash

ROLE=$1
ADMIN_USER=root
MASTER_HOST=192.168.50.31
SLAVE_USER=slave
SLAVE_PASS=slavepw
FLOATING_IP=192.168.50.30
FLOATING_DEV=eth1


[ -z $ROLE ] && exit

# Disable iptables
echo "Stopping firewall..."
service iptables stop 2>&1 >> /dev/null

# Install mysql-server if not already installed
echo "Verifying mysql server is installed..."
rpm -q --quiet mariadb-server || yum install -y mariadb-server mariadb-devel

echo "Verifying ruby is installed..."
rpm -q --quiet ruby || yum install -y ruby ruby-devel

# Cleanup any old replication settings
echo "Cleaning up old mysql instance..."
systemctl stop mariadb.service 2>&1 > /dev/null
rm -rf /var/lib/mysql/*

# Start mysqld
echo "Verifying mysqld is running..."
systemctl status mariadb.service 2>&1 >> /dev/null || systemctl start mariadb.service 2>&1 > /dev/null

# MySQL user setup
echo "Granting remote root access..."
/usr/bin/mysql -u $ADMIN_USER -e "GRANT ALL PRIVILEGES ON *.* TO '${ADMIN_USER}'@'%'; FLUSH PRIVILEGES;"

echo "Granting replication access..."
/usr/bin/mysql -u $ADMIN_USER -e "GRANT REPLICATION SLAVE ON *.* TO '${SLAVE_USER}'@'%' IDENTIFIED BY '${SLAVE_PASS}'; FLUSH PRIVILEGES;"


# Link in our configuration files
if [ ! -L /etc/my.cnf ]; then
  rm -f /etc/my.cnf
  ln -s /vagrant/vagrant-configs/${ROLE}.cnf /etc/my.cnf
  systemctl restart mariadb.service 
fi

# Setup one system to be a slave to start with
if [ "${ROLE}" == "slave" ]; then
  echo "Checking Replication Status..."
  SLAVE_RUNNING=$(/usr/bin/mysql -u $ADMIN_USER -e "SHOW SLAVE STATUS\G" | grep -c -e "Slave_IO_State: Waiting")
  if [ "${SLAVE_RUNNING}" != "1" ]; then
    echo "Initiating Replication..."
    /usr/bin/mysql -u $ADMIN_USER -e "CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}', MASTER_USER='${SLAVE_USER}', MASTER_PASSWORD='${SLAVE_PASS}', MASTER_LOG_FILE='', MASTER_LOG_POS=4"
  fi
  echo "Forcing slave to be read-only..."
  /usr/bin/mysql -u $ADMIN_USER -e "SET GLOBAL read_only = on"
fi

if [ "${ROLE}" == "master" ]; then
  echo "Checking for Floating VIP..."
  /sbin/ip addr list | grep "${FLOATING_IP}" 2>&1 > /dev/null
  if [  $? == 1 ]; then
    echo "Installing Floating VIP ${FLOATING_IP}..."
    /sbin/ip addr add ${FLOATING_IP} dev ${FLOATING_DEV}
  fi
fi

