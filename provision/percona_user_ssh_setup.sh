#!/bin/bash
set -euo pipefail

echo "[INFO] Creating percona user (if needed)..."
if ! id percona &>/dev/null; then
    sudo useradd -m -s /bin/bash percona
fi
echo 'percona ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/percona > /dev/null
sudo chmod 0440 /etc/sudoers.d/percona

echo "[INFO] Setting up SSH authorized_keys for percona user..."
if [ -f /vagrant/provision/monitor_id_rsa.pub ]; then
    sudo -u percona mkdir -p /home/percona/.ssh
    cat /vagrant/provision/monitor_id_rsa.pub | sudo tee -a /home/percona/.ssh/authorized_keys > /dev/null
    sudo chown -R percona:percona /home/percona/.ssh
    sudo chmod 700 /home/percona/.ssh
    sudo chmod 600 /home/percona/.ssh/authorized_keys
fi

echo "[INFO] Copying .vagrant_profile to vagrant user's .profile..."
sudo cp /vagrant/provision/.vagrant_profile /home/vagrant/.profile
sudo chown vagrant:vagrant /home/vagrant/.profile 