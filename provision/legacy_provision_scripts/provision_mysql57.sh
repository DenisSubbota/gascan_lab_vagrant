#!/bin/bash
set -euo pipefail

# [INFO] Starting MySQL 5.7 provisioning

echo "[INFO] Updating apt cache..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[INFO] Installing wget and lsb-release..."
sudo apt-get install -y wget lsb-release > /dev/null 2>&1

# Install Percona Server 5.7 if not already installed
echo "[INFO] Checking for Percona Server 5.7 installation..."
if ! dpkg -l | grep -q percona-server-server-5.7; then
    echo "[INFO] Downloading Percona release package..."
    wget -q -O /tmp/percona-release_latest.$(lsb_release -sc)_all.deb https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1
    echo "[INFO] Installing Percona release package..."
    sudo dpkg -i /tmp/percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1
    echo "[INFO] Enabling Percona 5.7 repo..."
    sudo percona-release enable-only ps-57 > /dev/null 2>&1
    echo "[INFO] Updating apt cache (Percona repo)..."
    sudo apt-get update -qq > /dev/null 2>&1
    echo "[INFO] Preseeding Percona root password..."
    echo "percona-server-server-5.7 percona-server-server/root_password password" | sudo debconf-set-selections
    echo "percona-server-server-5.7 percona-server-server/root_password_again password" | sudo debconf-set-selections
    echo "[INFO] Installing Percona Server 5.7..."
    sudo -E DEBIAN_FRONTEND=noninteractive apt-get install -y percona-server-server-5.7 > /dev/null 2>&1
else
    echo "[INFO] Percona Server 5.7 already installed."
fi

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
prompt=mysql57> 
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
sudo cp /vagrant/config/mysql57.cnf /etc/mysql/my.cnf
sudo chown mysql:mysql /etc/mysql/my.cnf
sudo chmod 644 /etc/mysql/my.cnf

echo "[INFO] Restarting MySQL service..."
sudo service mysql restart

echo "[INFO] Waiting for MySQL to be ready..."
until sudo mysqladmin ping --silent; do
  sleep 2
done

echo "[INFO] Creating replication and monitoring users..."
sudo mysql < /vagrant/provision/mysql_users.sql

echo "[INFO] MySQL master status:"
sudo mysql -e "SHOW MASTER STATUS;"

echo "[INFO] mysql57 provisioning complete." 
