#!/bin/bash
set -euo pipefail

# [INFO] Starting MySQL 8.4 provisioning

echo "[INFO] Updating apt cache..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[INFO] Installing gnupg2, wget, lsb-release..."
sudo apt-get install -y gnupg2 wget lsb-release > /dev/null 2>&1

echo "[INFO] Downloading Percona release package..."
wget -q https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1

echo "[INFO] Installing Percona release package..."
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1

echo "[INFO] Enabling Percona 8.4 repo..."
sudo percona-release enable-only ps-84-lts release > /dev/null 2>&1

echo "[INFO] Updating apt cache (Percona repo)..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[INFO] Installing Percona Server 8.4..."
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
prompt=mysql84> 
EOF'
sudo chown percona:percona /home/percona/.my.cnf
sudo chmod 600 /home/percona/.my.cnf

echo "[INFO] Setting up SSH server..."
sudo mkdir -p /var/run/sshd
sudo service ssh restart

echo "[INFO] Setting up SSH authorized_keys for percona user..."
if [ -f /vagrant/provision/monitor_id_rsa.pub ]; then
    sudo -u percona mkdir -p /home/percona/.ssh
    cat /vagrant/provision/monitor_id_rsa.pub | sudo tee -a /home/percona/.ssh/authorized_keys > /dev/null
    sudo chown -R percona:percona /home/percona/.ssh
    sudo chmod 700 /home/percona/.ssh
    sudo chmod 600 /home/percona/.ssh/authorized_keys
fi

echo "[INFO] Copying custom MySQL config..."
sudo cp /vagrant/config/mysql84.cnf /etc/mysql/my.cnf
sudo chown mysql:mysql /etc/mysql/my.cnf
sudo chmod 644 /etc/mysql/my.cnf

echo "[INFO] Restarting MySQL service..."
sudo service mysql restart

echo "[INFO] Waiting for MySQL to be ready..."
until mysqladmin ping --silent; do
  sleep 2
done

echo "[INFO] Creating monitoring user..."
sudo mysql < /vagrant/provision/mysql_users.sql

echo "[INFO] Setting up replication from mysql8 (intermediate)..."
sudo mysql -e "STOP REPLICA; RESET REPLICA ALL; CHANGE REPLICATION SOURCE TO SOURCE_HOST='192.168.56.180', SOURCE_PORT=3306, SOURCE_USER='percona', SOURCE_PASSWORD='Percona1234', SOURCE_AUTO_POSITION=1; START REPLICA;"

echo "[INFO] MySQL replica status:"
sudo mysql -e "SHOW REPLICA STATUS\\G"

echo "[INFO] mysql84 provisioning complete." 