#!/bin/bash
set -euo pipefail

# [INFO] Starting MySQL 8.0 provisioning

# TODO: Move hardcoded passwords to environment variables for better security

sudo apt-get update
sudo apt-get install -y mysql-server openssh-server sudo

# Create percona user with passwordless sudo
if ! id percona &>/dev/null; then
    sudo useradd -m -s /bin/bash percona
fi
echo 'percona ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/percona
sudo chmod 0440 /etc/sudoers.d/percona

echo 'percona:percona' | sudo chpasswd

# Create .my.cnf for percona user for easy mysql CLI access
sudo bash -c 'cat <<EOF > /home/percona/.my.cnf
[client]
user=percona
password=Percona1234
host=localhost
EOF'
sudo chown percona:percona /home/percona/.my.cnf
sudo chmod 600 /home/percona/.my.cnf

# Setup SSH server
sudo mkdir -p /var/run/sshd
sudo service ssh restart

# Add monitor's public key to authorized_keys for percona
if [ -f /vagrant/provision/monitor_id_rsa.pub ]; then
    sudo -u percona mkdir -p /home/percona/.ssh
    cat /vagrant/provision/monitor_id_rsa.pub | sudo tee -a /home/percona/.ssh/authorized_keys
    sudo chown -R percona:percona /home/percona/.ssh
    sudo chmod 700 /home/percona/.ssh
    sudo chmod 600 /home/percona/.ssh/authorized_keys
fi

# Copy custom config from config directory
sudo mkdir -p /etc/mysql/mysql.conf.d
sudo cp /vagrant/config/mysql8.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
sudo chown mysql:mysql /etc/mysql/mysql.conf.d/mysqld.cnf
sudo chmod 644 /etc/mysql/mysql.conf.d/mysqld.cnf

# Start MySQL
sudo service mysql start

# Wait for MySQL to be ready
until mysqladmin ping --silent; do
  sleep 2
done

# Create replication and monitoring users (idempotent)
sudo mysql < /vagrant/provision/mysql_users.sql

# Set up replication from mysql57 (source)
sudo mysql -e "STOP SLAVE; RESET SLAVE ALL; CHANGE MASTER TO MASTER_HOST='192.168.36.157', MASTER_PORT=3306, MASTER_USER='repl_user', MASTER_PASSWORD='repl_password', MASTER_AUTO_POSITION=1; START SLAVE;"

# Print status
sudo mysql -e "SHOW SLAVE STATUS\\G"

echo "[INFO] mysql8 provisioning complete." 