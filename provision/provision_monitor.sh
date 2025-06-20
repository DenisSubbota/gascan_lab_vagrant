#!/bin/bash
set -euo pipefail

# [INFO] Starting monitor provisioning

# TODO: Move hardcoded passwords to environment variables for better security

# Install only essential packages for user/ssh/ansible setup
sudo apt-get update
sudo apt-get install -y openssh-client openssh-server curl ansible sudo iputils-ping vim

# Create percona user with passwordless sudo if not exists
if ! id percona &>/dev/null; then
    sudo useradd -m -s /bin/bash percona
fi
sudo mkdir -p /etc/sudoers.d
sudo bash -c "echo 'percona ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/percona"
sudo chmod 0440 /etc/sudoers.d/percona

echo 'percona:percona' | sudo chpasswd

# Enable password authentication for SSH
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo mkdir -p /var/run/sshd
sudo service ssh restart

# Add user public key for SSH login
# Export USER_PUB_KEY from /vagrant/config/.env if present
if [ -f /vagrant/config/.env ]; then
  export USER_PUB_KEY=$(grep '^USER_PUB_KEY=' /vagrant/config/.env | cut -d'=' -f2-)
fi
sudo -u percona mkdir -p /home/percona/.ssh
if [ -n "$USER_PUB_KEY" ] && ! sudo grep -q "$USER_PUB_KEY" /home/percona/.ssh/authorized_keys 2>/dev/null; then
  echo "$USER_PUB_KEY" | sudo tee -a /home/percona/.ssh/authorized_keys
fi
sudo chown -R percona:percona /home/percona/.ssh
sudo chmod 700 /home/percona/.ssh
sudo chmod 600 /home/percona/.ssh/authorized_keys

echo "[INFO] Generating SSH key for percona if not exists..."
# Generate SSH key for percona if not exists
sudo -u percona bash -c '[ -f /home/percona/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f /home/percona/.ssh/id_rsa'

# Copy public key to shared location for MySQL nodes to use
sudo cp /home/percona/.ssh/id_rsa.pub /vagrant/provision/monitor_id_rsa.pub
sudo chmod 644 /vagrant/provision/monitor_id_rsa.pub

echo "[INFO] Creating .my.cnf for percona user..."
# Create .my.cnf for percona user for easy mysql CLI access
sudo bash -c 'cat <<EOF > /home/percona/.my.cnf
[client]
user=percona
password=Percona1234
EOF'
sudo chown percona:percona /home/percona/.my.cnf
sudo chmod 600 /home/percona/.my.cnf


echo "[INFO] Sourcing .env file from /vagrant/config/.env if present..."
# Parse .env and convert to --extra-vars format
if [ -f /vagrant/config/.env ]; then
  ENV_VARS=$(grep -v '^#' /vagrant/config/.env | xargs)
else
  ENV_VARS=""
fi

echo "[INFO] Running Ansible playbook for monitor configuration..."
# Run the Ansible playbook for monitor configuration (idempotent)
export ANSIBLE_HOST_KEY_CHECKING=False
sudo ansible-playbook /vagrant/provision/playbook_monitor.yml -i localhost, --extra-vars "$ENV_VARS" || {
  echo "[ERROR] Ansible playbook failed"; exit 1;
}

# Extract GASCAN* lines from percona's .bashrc to /tmp/.gascan_env
sudo egrep 'ANSIBLE_VAULT_PASSWORD_FILE|GASCAN_DEFAULT_INVENTORY|GASCAN_INVENTORY_CONFIG_FILE|GASCAN_FLAG_PASSWORDLESS_SUDO' /home/percona/.bashrc | sudo tee /tmp/.gascan_env > /dev/null

echo "[INFO] Running gascan as percona user..."
# Run gascan as percona user with environment loaded
sudo -u percona -i /bin/bash -c 'source /tmp/.gascan_env && /home/percona/bin/gascan --limit=monitors'

echo "[INFO] Monitor provisioning complete."
