#!/bin/bash
set -e

# Install ProxySQL
sudo apt-get update
sudo apt-get install -y wget lsb-release gnupg2
wget -O- https://repo.proxysql.com/ProxySQL/repo_pub_key | sudo apt-key add -
echo "deb https://repo.proxysql.com/ProxySQL/proxysql-2.5.x/$(lsb_release -sc)/ ./" | sudo tee /etc/apt/sources.list.d/proxysql.list
sudo apt-get update
sudo apt-get install -y proxysql

# Stop ProxySQL if running
sudo systemctl stop proxysql || true

# Copy config
sudo cp /vagrant/config/proxysql1.cnf /etc/proxysql.cnf
sudo chown proxysql:proxysql /etc/proxysql.cnf

# Start ProxySQL with new config
sudo systemctl start proxysql

# Load config to runtime and save
mysql -u admin -padmin -h 127.0.0.1 -P6032 -e "LOAD PROXYSQL SERVERS FROM CONFIG; LOAD MYSQL SERVERS FROM CONFIG; SAVE SERVERS TO DISK; SAVE MYSQL SERVERS TO DISK;" 