#!/bin/bash
set -euo pipefail

# [INFO] Starting MySQL 8.0 provisioning

echo "[INFO] Updating apt cache..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[INFO] Installing gnupg2, wget, lsb-release..."
sudo apt-get install -y gnupg2 wget lsb-release > /dev/null 2>&1

echo "[INFO] Downloading Percona release package..."
wget -q https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1

echo "[INFO] Installing Percona release package..."
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1

echo "[INFO] Enabling Percona 8.0 repo..."
sudo percona-release enable-only ps-80 > /dev/null 2>&1

echo "[INFO] Updating apt cache (Percona repo)..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[INFO] Installing Percona Server 8.0..."
sudo -E DEBIAN_FRONTEND=noninteractive apt-get install -y percona-server-server > /dev/null 2>&1

# TODO: Move hardcoded passwords to environment variables for better security

echo "[INFO] Creating percona user (if needed)..."
if ! id percona &>/dev/null; then
    sudo useradd -m -s /bin/bash percona
fi
echo 'percona ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/percona > /dev/null
sudo chmod 0440 /etc/sudoers.d/percona
echo 'percona:percona' | sudo chpasswd

echo "[INFO] Copying .vagrant_profile to vagrant user's .profile..."
sudo cp /vagrant/provision/.vagrant_profile /home/vagrant/.profile
sudo chown vagrant:vagrant /home/vagrant/.profile


echo "[INFO] Creating .my.cnf for percona user..."
sudo bash -c 'cat <<EOF > /home/percona/.my.cnf
[client]
user=percona
password=Percona1234
host=localhost
prompt=mysql8> 
EOF'
sudo chown percona:percona /home/percona/.my.cnf
sudo chmod 600 /home/percona/.my.cnf

echo "[INFO] Setting up SSH authorized_keys for percona user..."
if [ -f /vagrant/provision/monitor_id_rsa.pub ]; then
    sudo -u percona mkdir -p /home/percona/.ssh
    cat /vagrant/provision/monitor_id_rsa.pub | sudo tee -a /home/percona/.ssh/authorized_keys > /dev/null
    sudo chown -R percona:percona /home/percona/.ssh
    sudo chmod 700 /home/percona/.ssh
    sudo chmod 600 /home/percona/.ssh/authorized_keys
fi

echo "[INFO] Copying custom MySQL config..."
sudo cp /vagrant/config/mysql8.cnf /etc/mysql/my.cnf
sudo chown mysql:mysql /etc/mysql/my.cnf
sudo chmod 644 /etc/mysql/my.cnf

echo "[INFO] Restarting MySQL service..."
sudo service mysql restart

echo "[INFO] Waiting for MySQL to be ready..."
until mysqladmin ping --silent; do
  sleep 2
done

echo "[INFO] Creating replication and monitoring users..."
sudo mysql < /vagrant/provision/mysql_users.sql

echo "[INFO] Setting up replication from mysql57 (source)..."
sudo mysql -e "STOP SLAVE; RESET SLAVE ALL; CHANGE MASTER TO MASTER_HOST='192.168.56.157', MASTER_PORT=3306, MASTER_USER='repl_user', MASTER_PASSWORD='repl_password', MASTER_AUTO_POSITION=1; START SLAVE;"

echo "[INFO] MySQL slave status:"
sudo mysql -e "SHOW SLAVE STATUS\\G"

echo "[INFO] mysql8 provisioning complete." 