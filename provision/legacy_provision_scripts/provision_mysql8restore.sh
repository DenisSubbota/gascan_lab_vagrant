#!/bin/bash
set -euo pipefail

# [INFO] Starting MySQL 8.0 Restore provisioning

echo "[INFO] Updating apt cache..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[INFO] Installing gnupg2, wget, lsb-release..."
sudo apt-get install -y gnupg2 wget lsb-release > /dev/null 2>&1

echo "[INFO] Downloading Percona release package..."
wget -q https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1

echo "[INFO] Installing Percona release package..."
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb > /dev/null 2>&1

echo "[INFO] Enabling Percona 8.0 repo..."
sudo percona-release enable-only ps-80 release > /dev/null 2>&1

echo "[INFO] Updating apt cache (Percona repo)..."
sudo apt-get update -qq > /dev/null 2>&1

echo "[INFO] Installing Percona Server 8.0..."
sudo -E DEBIAN_FRONTEND=noninteractive apt-get install -y percona-server-server > /dev/null 2>&1

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
sudo cp /vagrant/config/mysql8.cnf /etc/mysql/my.cnf
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

echo "[INFO] Preparing node as the restore instance"
echo "[INFO] Installing xtrabackup (compatible with MySQL 8.0)..."
sudo percona-release enable pxb-80 release > /dev/null 2>&1
sudo apt-get update -qq > /dev/null 2>&1
sudo apt install percona-xtrabackup-80 -y -qq> /dev/null 2>&1

echo "[INFO] Installing mydumper version 0.19.3-2 from official release..."
wget -q https://github.com/mydumper/mydumper/releases/download/v0.19.3-2/mydumper_0.19.3-2.jammy_amd64.deb -O /tmp/mydumper_0.19.3-2.jammy_amd64.deb
sudo dpkg -i /tmp/mydumper_0.19.3-2.jammy_amd64.deb > /dev/null 2>&1 || sudo apt-get install -f -y > /dev/null 2>&1
rm -f /tmp/mydumper_0.19.3-2.jammy_amd64.deb

echo "[INFO] Installing awscli..."
sudo apt-get install -y awscli > /dev/null 2>&1
sudo apt-get install -y s3cmd > /dev/null 2>&1

echo "[INFO] Creating backup directories and configuration paths..."
sudo mkdir -p /home/percona/bin
sudo mkdir -p /home/percona/.config/percona/backup/
sudo mkdir -p /var/log/percona/backups/
sudo mkdir -p /root/.config/percona/backup
sudo chown -R percona:percona /home/percona/bin /home/percona/.config/percona

# Download percona-backup binary
echo "[INFO] Downloading percona-backup binary..."
sudo wget --no-check-certificate -q https://cdba.percona.com/downloads/pex/backup/v0.5.3/amd64/ubuntu-jammy/percona-backup3.10 -O /home/percona/bin/percona-backup
sudo chmod +x /home/percona/bin/percona-backup
sudo chown percona:percona /home/percona/bin/percona-backup

# Instead of generating a new GPG key, import from backup node's exported keys
if [ -f /vagrant/provision/gpg_root_directory_encryption_pub_mysql8backup.asc ] && [ -f /vagrant/provision/gpg_root_directory_encryption_priv_mysql8backup.asc ]; then
  echo "[INFO] Importing GPG public and private keys for directory.encryption@percona.com from backup node..."
  sudo gpg --import /vagrant/provision/gpg_root_directory_encryption_pub_mysql8backup.asc
  sudo gpg --import /vagrant/provision/gpg_root_directory_encryption_priv_mysql8backup.asc
else
  echo "[WARNING] GPG key export files not found in /vagrant/provision. Skipping GPG import."
fi
sudo bash -c 'echo "password" > /root/.gpg_passphrase'

echo "[INFO] Copying backup_config8.yml to /home/percona/.config/percona/backup/backup_config.yml..."
sudo cp /vagrant/config/backup_config8.yml /home/percona/.config/percona/backup/backup_config.yml
sudo chown percona:percona /home/percona/.config/percona/backup/backup_config.yml

# Copy the empty backup driver config for restore
sudo cp /vagrant/config/backup_driver_restore8.yml /home/percona/.config/percona/backup/restore_config.yml
sudo chown percona:percona /home/percona/.config/percona/backup/restore_config.yml

# Check for S3 and AWS credentials in /vagrant/config/.env and configure if present
if [ -f /vagrant/config/.env ]; then
  S3_BUCKET=$(grep '^S3_BUCKET=' /vagrant/config/.env | cut -d'=' -f2- | tr -d '"')
  AWS_ACCESS_KEY_ID=$(grep '^AWS_ACCESS_KEY_ID=' /vagrant/config/.env | cut -d'=' -f2- | tr -d '"')
  AWS_SECRET_ACCESS_KEY=$(grep '^AWS_SECRET_ACCESS_KEY=' /vagrant/config/.env | cut -d'=' -f2- | tr -d '"')
  if [ -n "$S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "[INFO] S3 and AWS credentials found in .env, configuring for S3 access..."
    sudo sed -i "s|^  S3_BUCKET:.*|  S3_BUCKET: $S3_BUCKET|" /home/percona/.config/percona/backup/restore_config.yml
    sudo mkdir -p /root/.aws
    sudo bash -c "cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF"
    sudo bash -c "cat > /root/.aws/config <<EOF
[default]
region = us-east-1
output = json
EOF"
    sudo bash -c "cat > /root/.s3cfg <<EOF
[default]
access_key = $AWS_ACCESS_KEY_ID
secret_key = $AWS_SECRET_ACCESS_KEY
bucket_location = us-east-1
use_https = True
EOF"
    echo "[INFO] Verifying S3 access with s3cmd..."
    sudo s3cmd info "$S3_BUCKET" || echo '[WARNING] Could not access S3 bucket with s3cmd.'
    echo "[INFO] AWS CLI configured for root user."
  fi
fi

echo "[INFO] Copying .my.cnf for root user..."
sudo cp /home/percona/.my.cnf /root/.my.cnf
sudo chown root:root /root/.my.cnf
sudo chmod 600 /root/.my.cnf

echo "[INFO] Creating static xb_keyfile for xtrabackup encryption..."
echo -n "000000000000000000000000" | sudo tee /home/percona/.config/percona/backup/xb_keyfile > /dev/null
sudo chown percona:percona /home/percona/.config/percona/backup/xb_keyfile
sudo chmod 600 /home/percona/.config/percona/backup/xb_keyfile

echo "[INFO] Creating dir_encrypt.yml for directory encryption..."
sudo bash -c "cat > /root/.config/percona/backup/dir_encrypt.yml <<EOF
'encryption recipient': 'directory.encryption@percona.com'
'encryption home dir': '/root/.gnupg'
'max encryption processes': 5
'encryption nice': False
'gpg bin': '/usr/bin/gpg'
'encryption file filter': ''
EOF"


# Generate SSH keypair for root if not present and export public key for backup node
if [ ! -f /root/.ssh/id_rsa ]; then
  sudo mkdir -p /root/.ssh
  sudo ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa
  sudo chmod 700 /root/.ssh
  sudo chmod 600 /root/.ssh/id_rsa
fi
sudo cat /root/.ssh/id_rsa.pub > /vagrant/provision/mysql8restore_root_id_rsa.pub

echo "[INFO] mysql8restore provisioning complete." 