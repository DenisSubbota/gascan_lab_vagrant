#!/bin/bash
set -euo pipefail
# [INFO] Starting monitor provisioning
echo "[INFO] Installing Ansible..."
# Install Ansible
sudo apt-get update > /dev/null
sudo apt-get install -y ansible > /dev/null
echo "[INFO] Running Ansible playbook for monitor configuration..."
# Run the Ansible playbook for monitor configuration (idempotent)
export ANSIBLE_HOST_KEY_CHECKING=False
sudo ansible-playbook /vagrant/provision/ansible/site.yml -i /vagrant/provision/ansible/inventory/lab --limit monitors || {
  echo "[ERROR] Ansible playbook failed"; exit 1;
}

# Extract GASCAN* lines from percona's .bashrc to /tmp/.gascan_env
sudo egrep 'ANSIBLE_VAULT_PASSWORD_FILE|GASCAN_DEFAULT_INVENTORY|GASCAN_INVENTORY_CONFIG_FILE|GASCAN_FLAG_PASSWORDLESS_SUDO' /home/percona/.bashrc | sudo tee /tmp/.gascan_env > /dev/null

echo "[INFO] Running gascan as percona user..."
# Run gascan as percona user with environment loaded
sudo -u percona -i /bin/bash -c 'source /tmp/.gascan_env && /home/percona/bin/gascan --limit=monitors'

echo "[INFO] Monitor provisioning complete."
